#include <janet.h>

JANET_FN(cfun_add,
         "(example-native/add x y)",
         "Adds two numbers.") {
    janet_fixarity(argc, 2);
    return janet_wrap_number(janet_getnumber(argv, 0) + janet_getnumber(argv, 1));
}

static const JanetReg cfuns[] = {
    JANET_REG("add", cfun_add),
    JANET_REG_END
};

JANET_MODULE_ENTRY(JanetTable *env) {
    janet_cfuns(env, "example-native", cfuns);
}
