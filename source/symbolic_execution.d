module symbolic_execution;

enum kernel = 1;

import io = std.stdio;

int indent_level = 0;
scope class Indent {
  this() {
    indent_level++;
  }
  ~this() {
    indent_level--;
  }
}

void writefln(Args...)(string fmt, Args args) {
  // debug io.writefln("In our writefln. Indent_level = %d", indent_level);
  io.writefln("%*s" ~ fmt, 4 * indent_level, "", args);
}

version (ctfe) {
} else {
  Program* program_;
}

struct Literal(T) {
 private:
  T value_;
  //Program* program_;

 public:
  this(T value) {
    value_ = value;
  }

  // toString is recursive.
  string toString() const {
    import std.format;
    return format!("Literal!" ~ T.stringof ~ "(%s)")(value_);
  }

  // idString only shows this variable.
  string idString() const {
    return toString();
  }
}

// We need to use a struct, because we want to be able to use opAssign,
// as this allows a way easier tracking of writes to variables.
//
// This can be emulated using classes, but is very hard, because
// a program can for example assing to a variable (really a reference
// to the class), and then back to the original value, and because
// it could possibly be important, we would miss it.
// It is possible that that is not important, and we would still capture
// proper program and data flow, using temporary that is referenced by
// this assignment, but it is unclear at the moment.
struct Var(T) {
 private:
  string name_;
  Var!T* current_value_;
  int id_;

  // version (ctfe) {
  // Program* program;
  // }
  Program program_;  // reference

  static int ids_ = 0;

 public:
  void newid() {
    id_ = program_.ids_++;
  }

//  this(string name, Program* program) {
  this(string name, Program program) {
    name_ = name;
    program_ = program;
    newid();
  }
  auto opBinary(string s)(Var!T other) {
    return OpBinary!(T, s)(this, other);
  }

  Condition!(Var!T, Var!T) Lt(Var!T other) {
//    writefln("Var!" ~ T.stringof ~ ".Lt(%s/%d, %s/%d)", name_, id_, other.name_, other.id_);
    return Condition!(Var!T, Var!T)(this, other, "<");
  }
  Condition!(Var!T, Literal!T) Lt(T other) {
//    writefln("Var!" ~ T.stringof ~ ".Lt(%s/%d, Literal(%s))", name_, id_, other);
    return Condition!(Var!T, Literal!T)(this, Literal!(T)(other), "<");
  }

  Condition!(Var!T, Var!T) Eq(Var!T other) {
    return Condition!(Var!T, Var!T)(this, other, "==");
  }
  Condition!(Var!T, Literal!T) Eq(T other) {
    return Condition!(Var!T, Literal!T)(this, Literal!(T)(other), "==");
  }

  /*
  Condition opCmp(Var!T other) {
    return Condition();
  }
  Condition opCmp(T other) {
    return Condition();
  }
  Condition opEquals(Var!T other) {
    return Condition();
  }
  Condition opEquals(T other) {
    return Condition();
  }
  */

  // TODO: In place operations.


  void opAssign(Var!T rhs) {
    writefln("Var!" ~ T.stringof ~ "(%s/%d) <= Var!" ~ T.stringof ~ ".opAssign(Var!" ~ T.stringof ~"(%s/%d))", name_, id_, rhs.name_, rhs.id_);
    // current_value_ = rhs;
  }

  // toString is recursive.
  string toString() const {
    import std.format;
    return format!("Var!" ~ T.stringof ~ "(%s/%d)")(name_, id_);
  }

  // idString only shows this variable.
  string idString() const {
    import std.format;
    return format!("Var!" ~ T.stringof ~ "(%s/%d)")(name_, id_);
  }
}

struct OpBinary(T, string s) {
  static string s_ = s;

  Var!T result_;
  alias result_ this;  // To implement opBinary, Lt, Eq, opAssign, etc.

 public:
  this(Var!T left, Var!T right) {
    left_ = left;
    right_ = right_;
    assert(left.program_ is right.program_);
    result_.program_ = left.program_;
    result_.newid();
    writefln("Var!" ~ T.stringof ~ "(%s/%d) <= Var!" ~ T.stringof ~ ".opBinary!\"" ~ s ~ "\"(%s/%d, %s/%d)", result_.name_, result_.id_, left.name_, left.id_, right.name_, right.id_);
  }
  Var!T left_;
  Var!T right_;

  // void opAssign(Var!T rhs) {
  // }
  // void opAssign(OpBinary!T rhs) {
  // }

  import std.array : appender;
  import std.range.primitives : put;

  // void toString(W)(ref W writer, scope const ref FormatSpec!char f) if (isOutputRange!(W, char)) {
  //   put(writer, "Var!" ~ T.stringof ~ "(");
  //   // formatValue(writer, x, f);
  //   // formatValue(writer, y, f);
  // }

  string toString() const {
    import std.format : format;
    return format!("Var!" ~ T.stringof ~ "(%s/%d) /* %s %s %s */")(result_.name_, result_.id_, left_.idString(), s, right_.idString());
  }

  string idString() const {
    import std.format : format;
    return format!("Var!" ~ T.stringof ~ "(%s/%d) /* %s %s %s */")(result_.name_, result_.id_, left_.idString(), s, right_.idString());
  }
}

// Not in the struct Condition, to share ids between differ types of Conditions instead.
int condition_ids_ = 0;

// Condition is basically a Var!bool.
struct Condition(Left, Right) {
  Left left_;
  Right right_;
  string type_;
  int condition_id_;

  // Program* program_;
  Program program_;  // reference

  void newid() {
    condition_id_ = program_.condition_ids_++;
  }

  this(Left left, Right right, string type) {
    left_ = left;
    right_ = right_;

    type_ = type;
    assert(type == "<" || type == "<=" || type == ">=" || type == ">" || type == "==");

    static if (__traits(compiles, left.program_) && __traits(compiles, right.program_)) {
    assert(left.program_ is right.program_);
    }

    static if (__traits(compiles, left.program_)) {
      program_ = left.program_;
    } else static if (__traits(compiles, right.program_)) {
      program_ = right.program_;
    } else {
      static assert(__traits(compiles, left.value_) && __traits(compiles, right.value_));
      bool constant_result;
      switch (type) {
        case "==": constant_result = left.value_ == right.value_; break;
        case "<": constant_result = left.value_ < right.value_; break;
        case "<=": constant_result = left.value_ <= right.value_; break;
        case ">=": constant_result = left.value_ >= right.value_; break;
        case ">": constant_result = left.value_ > right.value_; break;
      }

      static assert(false, "Both left and right operands to Condition constructor lack program pointer. Did you try to compare two literals?");
      // In fact if both are literals we can evaluate them immedietly,
      // and constant propagate the condition value.
    }

    newid();

    writefln("%s", idString());
  }

  // auto opBinary(string s)(Condition other) if (s == "&&" || s == "||" || s == "^^") {
  //   writefln("Condition opBinary!\"" ~ s ~ "\"(%s, %s)", type, other.type);
  //   return CombinedCondition(this, other, s);
  // }

  string toString() const {
    import std.format : format;
    return format!("Condition(/%d) ( %s %s %s )")(condition_id_, left_.idString(), type_, right_.idString());
  }
  string idString() const {
    return toString();
  }
}

struct CombinedCondition(ConditionA, ConditionB) {
  ConditionA left_;
  ConditionB right_;
  string type_;
  int condition_id_;

  void newid() {
    condition_id_ = condition_ids_++;
  }

  this(ConditionA left, ConditionB right, string type) {
    left_ = left;
    right_ = right;
    type_ = type;

    newid();

    writefln("%s", toString());
  }

  Var!bool result_;
  alias result_ this;


  string toString() const {
    import std.format : format;
    return format!("CombinedCondition(/%d) = (%s) %s (%s)")(condition_id_, left_.idString(), type_, right_.idString());
  }
  string idString() const {
    import std.format : format;
    return format!("CombinedCondition(/%d)")(condition_id_);
  }
}

struct IfType {
  IfType If(ConditionType)(ConditionType if_condition, void delegate() then_if_dg) {
    writefln("Then");
    {
    scope indent = new Indent();

    // We do not pass Program to the delegate, explicitly (via arguments)
    // or implicitly (i.e. global variable).
    // Note that there are no inputs or outputs from the delegate. It can
    // only communicate by reading variables it has access to from the outer
    // scope, and communicate back using Return, or maybe Break / Continue.
    // Side effects like reading and writing to memory, or calling other
    // functions with side effects, still require reading SOME variable from
    // outer scope, to get a handle to the memory, so that is covered.

    then_if_dg();

    }
    return this;
  }

  IfType ElseIf(ConditionType)(ConditionType elseif_condition, void delegate() else_if_dg) {
    writefln("ElseIf");
    {
    scope indent = new Indent();
    else_if_dg();
    }
    return this;
  }
  void Else(void delegate() else_dg) {
    writefln("Else");
    {
      scope indent = new Indent();
      else_dg();
    }
  }
}

IfType If(ConditionType)(ConditionType if_condition, void delegate() then_dg, void delegate() else_dg = null) {
  writefln("If");
  {
    scope indent = new Indent();
    writefln("Condition %s", if_condition.idString());
  }

// TODO(baryluk): Inside If and Else branches we need to track opAssign that
// overwrites the variables, and restore them for Else. After If is finished we
// will know what happened.

  auto if_ = IfType();
  {
    scope indent = new Indent();
    if_.If!(ConditionType)(if_condition, then_dg);
  }
  if (else_dg !is null) {
    scope indent = new Indent();
    if_.Else(else_dg);
  }
  return if_;
}

void While(Condition)(Condition condition, void delegate() body) {
  
}
void DoWhile() {
}
void For() { // Init, Cond, Step, Body.
}

void Foreach() {
}
void D_Foreach() {
}
void D_ForeachReverse() {
}

void Break() {
}

void Continue() {
}

void Goto(string label) {
}
void Label(string label) {
}
void* NewLabel() {
  return null;
}

void Return(T)(const Var!T var) {
  writefln("Return(%s)", var.idString());
  return;
}

Var!T FunctionCall(T)(string func_name) {  // Return values, add some more magic.
  return Var!T("r");
}

void MemoryStore() {  // Add flags, like volatile, non-volatile, atomic / non-atomic.
}
// T MemoryLoad() {  // Add flags, like volatile, non-volatile, atomic / non-atomic.
//}

void MemoryAtomicOp() {
}

struct Array(T) {
}



// Program state is a currently evaluated frame (i.e. function call),
// or a branch of the if/else/then, or a loop (while, for, foreach).
// It can also in the future be used to put program state checkpoint,
// if we implement Label() and Goto().
class ProgramState {
}

class Program {
  int ids_ = 0;
  int condition_ids_ = 0;
  ProgramState[] state_stack_;

  Var!T newVar(T)(string name) {
    return Var!T(name, this);
  }
}

version (ctfe) {
} else {
// Program program_ = null;
}

CombinedCondition!(ConditionA, ConditionB) And(ConditionA, ConditionB)(ConditionA a, ConditionB b) {
  return CombinedCondition!(ConditionA, ConditionB)(a, b, "&&");
}
CombinedCondition!(ConditionA, ConditionB) Or(ConditionA, ConditionB)(ConditionA a, ConditionB b) {
  return CombinedCondition!(ConditionA, ConditionB)(a, b, "||");
}
CombinedCondition!(ConditionA, ConditionB) Xor(ConditionA, ConditionB)(ConditionA a, ConditionB b) {
  return CombinedCondition!(ConditionA, ConditionB)(a, b, "^^");
}
//CombinedCondition!(ConditionA) Not(ConditionA a) {
//  return CombinedCondition!(ConditionA)(a, b, "!");
//}



void optimize(Program program) {
}


void interpreter(Program program) {
}

void convert_to_D(Program program) {
}

void convert_to_OpenCL(Program program) {
}

