#include <ruby.h>

static VALUE hola(VALUE self) {
  return rb_str_new2("hola");
}

void Init_ext() {
  VALUE klass = rb_define_module("Hello");
  rb_define_singleton_method(klass, "hola", hola, 0);
}
