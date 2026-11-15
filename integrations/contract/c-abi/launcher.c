/* SPDX-License-Identifier: MPL-2.0 */
/* SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) */
/*
 * Distinguish actual invocation from an executed subject's exit code.
 * Unlike timeout's raw exit status, 125/126/127 from the child are failures,
 * not a claim that the child did not start. POSIX host-only test launcher.
 * 0 = launched and exited 0; 1 = launched, failed or signaled;
 * 2 = spawn/exec/status plumbing could not perform the check.
 */
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

static int await_child(pid_t pid, int *status) {
    for (;;) {
        if (waitpid(pid, status, 0) >= 0) return 0;
        if (errno != EINTR) return -1;
    }
}

int main(int argc, char **argv) {
    int wire[2];
    int exec_error = 0;
    ssize_t received;
    pid_t pid;
    int status = 0;

    if (argc < 2) {
        fputs("NOT RUN: executable path absent\n", stderr);
        return 2;
    }
    if (pipe(wire) != 0 || fcntl(wire[1], F_SETFD, FD_CLOEXEC) == -1) {
        fputs("NOT RUN: cannot establish execution handshake\n", stderr);
        return 2;
    }
    pid = fork();
    if (pid < 0) {
        close(wire[0]);
        close(wire[1]);
        fputs("NOT RUN: cannot create test process\n", stderr);
        return 2;
    }
    if (pid == 0) {
        int saved;
        close(wire[0]);
        execv(argv[1], &argv[1]);
        saved = errno;
        /* This write is atomic (< PIPE_BUF), for an exec failure only. */
        (void)write(wire[1], &saved, sizeof(saved));
        _exit(127);
    }
    close(wire[1]);
    do {
        received = read(wire[0], &exec_error, sizeof(exec_error));
    } while (received == -1 && errno == EINTR);
    close(wire[0]);
    if (await_child(pid, &status) != 0 || received != 0) {
        fprintf(stderr, "NOT RUN: child exec failed or handshake invalid (errno=%d)\n", exec_error);
        return 2;
    }
    if (WIFEXITED(status)) {
        int code = WEXITSTATUS(status);
        if (code == 0) return 0;
        fprintf(stderr, "FAIL: executed ABI consumer exited %d\n", code);
        return 1;
    }
    if (WIFSIGNALED(status)) {
        fprintf(stderr, "NOT RUN: ABI consumer crashed or was signaled before completion (signal %d)\n", WTERMSIG(status));
        return 2;
    }
    fputs("NOT RUN: child did not produce a terminal result\n", stderr);
    return 2;
}
