## :Author: Jacob VanDrunen
## :License: ISC
##
## A helper module for writing unit tests with nake or similar build system.
## Automatically discovers all tests in a test directory, along with all of
## their dependencies, so one can determine whether a given test needs to be
## rebuilt.
##
## Example usage:
##
## .. code-block:: nim
##  
##  import nake
##  import findtests
##
##  task "test", "Update module builds and run tests":
##    for testSrcs in findTests("./tests"):
##      let target = testSrcs[0][0..^5]  # the build target (without .nim)
##      if needsRefresh(target, testSrcs):
##        direShell(nimExe, "c", "-r", target)

import sets
import strutils
import osproc
import os
import sequtils
import strformat

proc joinPaths(path1, path2: string): string =
  if path1[^1] == '/':
    path1 & path2
  else:
    path1 & "/" & path2

proc parentPath(path: string): string =
  var i = path.len - 2  # ignore trailing slash
  while path[i] != '/':
    dec i
  path[0..i]

proc expandPath(filename, root: string): string =
  if filename[0..1] == "./":
    joinPaths(root, filename[2..^1])
  elif filename[0..2] == "../":
    joinPaths(parentPath(root), filename[3..^1])
  elif filename[0] == '/':
    filename
  else:
    joinPaths(root, filename)

proc followDependencyTree(path: string, includes: ptr HashSet[string]) =
  let imports = map(splitLines(execProcess("/bin/grep", @["import \\.\\|include \\.", path], options={})), proc(s: string): string = strip(s))
  let root = parentPath(path)
  for i in 0..imports.len-1:
    if imports[i].len > 0 and not includes[].contains(imports[i]):
      let newInclude = expandPath(strip(imports[i][7..^1]) & ".nim", root)
      includes[].incl(newInclude)
      followDependencyTree(newInclude, includes)

iterator findNimFiles(root: string): string =
  for file in walkDirRec(root):
    if file[^4..^1] == ".nim":
      yield file

proc getRelativeImports*(path: string): HashSet[string] =
  ## Recursively determine all modules imported relatively by the given file.
  result = initSet[string]()
  followDependencyTree(path, addr result)

proc generateTestsFile*(tests_file, tests_path: string, exclude: openarray[string]) =
  ## Find all Nim files in given directory and construct a new file which
  ## includes all of them.
  let testsDir = expandFilename(tests_path)
  var toExclude = initSet[string](exclude.len)
  for excludeFile in exclude:
    toExclude.incl(expandPath(excludeFile, testsDir))
  var f = open(tests_file, fmWrite)
  for testSrc in findNimFiles(testsDir):
    if toExclude.contains(testSrc):
      continue
    let m = testSrc[0..^5]
    f.writeLine(fmt"""include "{m}" """)
  f.close()

iterator findTests*(path: string, exclude: openarray[string]): seq[string] =
  ## Find all Nim files in given directory and (recursively) their local
  ## dependencies.
  let testsDir = expandFilename(path)
  var toExclude = initSet[string](exclude.len)
  for excludeFile in exclude:
    toExclude.incl(expandPath(excludeFile, testsDir))
  for testSrc in findNimFiles(testsDir):
    if toExclude.contains(testSrc):
      continue
    yield concat(@[testSrc], toSeq(getRelativeImports(testSrc).items()))
