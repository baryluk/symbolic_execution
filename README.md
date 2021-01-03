Symbolic execution in D programming language

Just a silly, but interesting idea. Could be useful for translating into Vulkan
shaders, or OpenCL, or maybe doing other code analysis.

The code takes a D code, slightly modified to handle control flow, then executes
all possible code paths to capture what the code is doing. During this execution
it captures all operations. I call it symbolic execution. Once captures, this
information can be translated into AST of original code, or translated into other
language, for example to be executed on GPU.

Example:

```d
import symbolic_execution;

@kernel
auto kernel_a(Var!int a, Var!int b) {
  auto apb = a + b;
  auto amb = a - b;

  If(Or(And(amb.Lt(42), apb.Lt(amb)), amb.Lt(666)), (){
    apb = apb + b;
    Return(apb * amb);
  }, () {
    If (amb.Eq(apb), (){
      Return(apb / amb);
    });
  });

  Return(apb * amb);
  return program_;
}

int main() {
  auto program = new Program();

  auto a = program.newVar!int("a");
  auto b = program.newVar!int("b");
  auto kernel_ast_return = kernel_a(a, b);

  return 0;
}
```

Produced AST:


```
Var!int(/2) <= Var!int.opBinary!"+"(a/0, b/1)
Var!int(/3) <= Var!int.opBinary!"-"(a/0, b/1)
Condition(/0) ( Var!int(/3) < Literal!int(0) )
Condition(/1) ( Var!int(/2) < Var!int(/0) )
CombinedCondition(/0) = (Condition(/0) ( Var!int(/3) < Literal!int(0) )) && (Condition(/1) ( Var!int(/2) < Var!int(/0) ))
Condition(/2) ( Var!int(/3) < Literal!int(0) )
CombinedCondition(/1) = (CombinedCondition(/0)) || (Condition(/2) ( Var!int(/3) < Literal!int(0) ))
If
    Condition CombinedCondition(/1)
    Then
        Var!int(/4) <= Var!int.opBinary!"+"(/2, b/1)
        Var!int(/2) <= Var!int.opAssign(Var!int(/4))
        Var!int(a/0) <= Var!int.opAssign(Var!int(/2))
        Var!int(/0) <= Var!int.opAssign(Var!int(/0))
        Var!int(/5) <= Var!int.opBinary!"*"(/2, /3)
        Return(Var!int(/5))
    Else
        Condition(/3) ( Var!int(/3) == Var!int(/0) )
        If
            Condition Condition(/3) ( Var!int(/3) == Var!int(/0) )
            Then
                Var!int(/6) <= Var!int.opBinary!"/"(/2, /3)
                Return(Var!int(/6))
Var!int(/7) <= Var!int.opBinary!"*"(/2, /3)
Return(Var!int(/7))
```


TODO(baryluk): Translate into OpenCL kernels.

TODO(baryluk): Model memory read and writes.

TODO(baryluk): Make it CTFE-able. So we can do symbolic execution of `@kernel` at
compile time, translate to OpenCL at compile time, and then at runtime load it.
Or other crazy things.
