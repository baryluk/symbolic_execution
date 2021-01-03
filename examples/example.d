import symbolic_execution;

// @kernel_sub
auto subroutine(T)(T x, T y) {
  return x + y * y;
}

@kernel
auto kernel_a(Var!int a, Var!int b) {
  auto apb = a + b;
  auto amb = a - b;

  // auto l = a < b;
  //   Error: incompatible types for (a.opCmp(b)) < (0): Condition and int

  // auto two = amb.Lt(0) && apb.Lt(amb);
  //   Error: expression amb.result_.Lt(0) of type Condition does not have a boolean value
  //   Error: expression apb.result_.Lt(amb.result_) of type Condition does not have a boolean value

  // If(amb.Lt(0).And(apb.Lt(amb))), (){

  // auto prog = a.program();

  If(Or(And(amb.Lt(42), apb.Lt(amb)), amb.Lt(666)), (){
    apb = apb + b;
    Return(apb * amb);
  }, () {
    //apb +=
    // subroutine(a, b);
    If (amb.Eq(apb), (){
      Return(apb / amb);
    });
  });

  Return(apb * amb);
  return program_;
}

// We could use a a global (thread-local) variable for Program,
// which would be accessed by all operators and keywords implicitly,
// but that would make impossible to run the magic code as CTFE.
// So instead we create a explicit program and poison all variables
// and expressions to track it.
// Operators will check if both operands use same program, and propagate
// it to the result. Conditions the same. If, ElseIf, Switch, Return with
// value, will do similar.
//
// Only exceptions that need special handling are keywords that don't take
// argument. So Return without value, Break, Continue, Label, and possibly Goto.
// The code would need to explicitly extract a program pointer from one of its
// vars, and use methods on it. Similarly functions with no arguments, might
// need a dummy parameter to propagate the program.
//
// This is a bit wasteful for use at runtime, as each variable will need to
// carry the pointer to the program.
//
// In the future we might maybe create separate variable representations for
// CTFE and non-CTFE, while still using same user provided code.

int main() {
  auto program = new Program();

  auto a = program.newVar!int("a");
  auto b = program.newVar!int("b");
  auto kernel_ast_return = kernel_a(a, b);

  return 0;
}
