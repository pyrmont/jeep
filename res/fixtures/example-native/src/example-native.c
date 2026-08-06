#include <janet.h>

JANET_FN(cfun_add, "(example-native/add x y)", "Adds two numbers.") {
    janet_fixarity(argc, 2);
    return janet_wrap_number(janet_getnumber(argv, 0) + janet_getnumber(argv, 1));
}

static Janet cfun_legacy(int32_t argc, Janet *argv) {
    (void) argv;
    janet_fixarity(argc, 0);
    return janet_wrap_nil();
}

JANET_MODULE_ENTRY(JanetTable *env) {
    JanetRegExt cfuns[] = {
        JANET_REG("add", cfun_add),
        JANET_REG_END
    };
    JanetReg legacy_cfuns[] = {
        {"legacy", cfun_legacy, NULL},
        {NULL, NULL, NULL}
    };
    janet_cfuns_ext(env, "example-native", cfuns);
    janet_cfuns(env, "example-native", legacy_cfuns);
}
