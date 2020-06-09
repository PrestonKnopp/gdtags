template decho*(args: untyped): untyped =
  when not defined(release):
    echo args

template eecho*(args: varargs[string, `$`]) =
  stderr.writeLine args

