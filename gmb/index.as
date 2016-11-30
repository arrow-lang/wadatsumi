import "./machine";

def main(argc: int32, argv: *str) {
  let m = machine.Machine.New();

  // HACK: Taking the address of a reference (`self`) dies
  m.Acquire(&m);

  m.Open(*(argv + 1));
  m.Reset();

  while true {
    m.Run();
  }

  m.Release();
}
