# findtests

A helper module for writing unit tests with nake or similar build system. Automatically discovers all tests in a test directory, along with all of their dependencies, so one can determine whether a given test needs to be rebuilt.

Example usage:

```Nim
import nake
import findtests

task "test", "Update module builds and run tests":
  for testSrcs in findTests("./tests"):
    let target = testSrcs[0][0..^5]  # the build target (without .nim)
    if needsRefresh(target, testSrcs):
      direShell(nimExe, "c", "-r", target)
```
