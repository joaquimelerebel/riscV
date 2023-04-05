/**
 * A gcc plugin that add instructions needed for CFI
 * Heavily based on the blog post of Grabiele Serra :
 * https://gabrieleserra.ml/blog/2020-08-27-an-introduction-to-gcc-and-gccs-plugins.html
 */
#include <iostream>
#include <gcc-plugin.h>
#include <rtl.h>
#include <target.h>
#include <tree.h>
#include <tree-pass.h>
#include <stringpool.h>
#include <attribs.h>
#include <memmodel.h>
#include <emit-rtl.h>
#include <function.h>

#define INSN_FROM_RTX(rtx) (rtx_insn *)(rtx)

#define LI_MASK 0x00000013
#define CSRWI_3FE_MASK 0x3fe05073

#define LI_ZERO(imm) create_byte(((imm << 20) | LI_MASK))
#define CSRWI_3FE(imm) create_byte(((imm << 15) | CSRWI_3FE_MASK))
#define ASM_BUFFER_SIZE 100

char generic_asm[ASM_BUFFER_SIZE];

char *create_byte(uint32_t imm)
{
    snprintf(generic_asm, ASM_BUFFER_SIZE, ".word 0x%x", imm); //, ".byte 0x%02x, 0x%02x, 0x%02x, 0x%02x", imm & 0xff, (imm >> 8) & 0xff, (imm >> 16) & 0xff, (imm >> 24) & 0xff);
    return generic_asm;
}

/**
 * When 1 enables verbose printing
 */
#define DEBUG 1

/**
 * Generate code for runtime verification of number of arguments
*/
#define RUNTIME_ARG_CHECK 1 // 0

/**
 * Generate code for return verification
*/
#define RUNTIME_RET_ANNOTATION 0 // 1

/**
 * Generate code for call verification
*/
#define RUNTIME_CALL_ANNOTATION 1 // 0

/**
 * Name of this plugin
 */
#define PLUGIN_NAME "inst_plugin_cfi"

/**
 * Version of this plugin
 */
#define PLUGIN_VERSION "0.1"

/**
 * Help/usage string for the plugin
 */
#define PLUGIN_HELP "Usage: just do it"

/**
 * Required GCC version
 */
#define PLUGIN_GCC_BASEV "12.1.0"

// -----------------------------------------------------------------------------
// GCC PLUGIN SETUP (BASIC INFO / LICENSE / REQUIRED VERSION)
// -----------------------------------------------------------------------------

int plugin_is_GPL_compatible;

/**
 * Additional information about the plugin. Used by --help and --version
 */
static struct plugin_info inst_plugin_info =
    {
        .version = PLUGIN_VERSION,
        .help = PLUGIN_HELP,
};

/**
 * Represents the gcc version we need. Used to void using an incompatible plugin
 */
static struct plugin_gcc_version inst_plugin_ver =
    {
        .basever = PLUGIN_GCC_BASEV,
};

// -----------------------------------------------------------------------------
// GCC EXTERNAL DECLARATION
// -----------------------------------------------------------------------------

/**
 * Takes a tree node and returns the identifier string
 * @see https://gcc.gnu.org/onlinedocs/gccint/Identifiers.html
 */
#define FN_NAME(tree_fun) IDENTIFIER_POINTER(DECL_NAME(tree_fun))

/**
 * Takes a tree node and returns the identifier string length
 * @see https://gcc.gnu.org/onlinedocs/gccint/Identifiers.html
 */
#define FN_NAME_LEN(tree_fun) IDENTIFIER_LENGTH(DECL_NAME(tree_fun))

/**
 * Print GIMPLE statement G to FILE using SPC indentation spaces and FLAGS
 * @note Makes use of pp_gimple_stmt_1
 * @see Declared in gimple-pretty-print.h
 * @see Flags are listed in dumpfile.h
 */
extern void print_gimple_stmt(FILE *file, gimple *g, int spc, dump_flags_t flags);

/**
 * Print tree T, and its successors, on file FILE. FLAGS specifies details to
 * show in the dump
 * @note Makes use of dump_generic_node
 * @see Declared in tree-pretty-print.h
 * @see Flags are listed in dumpfile.h
 */
extern void print_generic_stmt(FILE *file, tree t, dump_flags_t flags);

/**
 * The global singleton context aka "g". The name is chosen to be easy to type
 * in a DEBUGger. Represents the 'global state' of GCC
 *
 * GCC's internal state can be divided into zero or more "parallel universe" of
 * state; an instance of the class context is one such context of state
 *
 * @see Declared in context.h
 */
extern gcc::context *g;

// -----------------------------------------------------------------------------
// PLUGIN INSTRUMENTATION LOGICS
// -----------------------------------------------------------------------------

/**
 * Take a basic block as input and seek the insn list until the function prologue
 */
rtx_insn *seek_till_fn_prologue(basic_block bb)
{
    rtx_insn *tmp_rtx;

    for (tmp_rtx = BB_HEAD(bb); tmp_rtx != 0; tmp_rtx = NEXT_INSN(tmp_rtx))
    {
        if ((GET_CODE(tmp_rtx) == NOTE) && (NOTE_KIND(tmp_rtx) == NOTE_INSN_FUNCTION_BEG))
            break;
    }

    return tmp_rtx;
}

/**
 * Create a nop instruction and insert it after the given stmt
 */

static void insert_asm(rtx_insn *insn, const char *opcode, bool before = false)
{
    tree string = build_string(strlen(opcode), opcode);
    location_t loc = INSN_LOCATION(insn) || INSN_LOCATION(BB_HEAD(ENTRY_BLOCK_PTR_FOR_FN(cfun)->next_bb)); // INSN_LOCATION(insn);

    rtx body = gen_rtx_ASM_INPUT_loc(VOIDmode, ggc_strdup(TREE_STRING_POINTER(string)), loc);
    if (before)
        emit_insn_before(body, insn);
    else
        emit_insn_after(body, insn);
}

/**
 * For each function lookup attributes and attach profiling function
 */

struct argument_count
{
    int count;
    bool is_variadic;
};

static void get_argument_count(tree fn, struct argument_count *p)
{
    int count = 0;

    tree arg = arg = TYPE_ARG_TYPES(TREE_TYPE(fn));
    for (int idx = 0; arg && arg != void_list_node; arg = TREE_CHAIN(arg), idx++)
        count++;

    p->count = count;
    p->is_variadic = (count && (arg != void_list_node));
}

int is_indirect_call(rtx_insn *insn)
{
    rtx pattern_expr = PATTERN(insn);

    if (GET_CODE(pattern_expr) == PARALLEL)
    {
        int num_ops = XVECLEN(pattern_expr, 0);
        for (int i = 0; i < num_ops; i++)
        {
            rtx op_expr = XVECEXP(pattern_expr, 0, i);
            if (GET_CODE(op_expr) == CALL)
            {
                return GET_CODE(XVECEXP(op_expr, 0, 0)) != SYMBOL_REF;
            }
            else if (GET_CODE(op_expr) == SET)
            {
                return GET_CODE(XEXP(XVECEXP(op_expr, 1, 0), 0)) != SYMBOL_REF;
            }
        }
    }

    return 0;
}

/* might break some code - be careful */
static int count_call_ins_arguments(rtx_insn *insn)
{
    int count = 0;
    rtx arg_list = CALL_INSN_FUNCTION_USAGE(insn);
    while (arg_list && GET_CODE(arg_list) == EXPR_LIST)
    {
        ++count;
        arg_list = XEXP(arg_list, 1);
    }

    return count;
}

static unsigned int instrument_assignments_plugin_exec(void)
{
    // get the FUNCTION_DECL of the function whose body we are reading
    tree fndef = current_function_decl;
#if DEBUG >= 1
    // print the function name
    fprintf(stderr, "\n> Inspecting function '%s' | RUNTIME_ARG_CHECK = %d\n", FN_NAME(fndef), RUNTIME_ARG_CHECK);
#endif 
    /* Traverse the parameter list and count the number of non-variadic parameters */

    // get function entry block
    basic_block entry = ENTRY_BLOCK_PTR_FOR_FN(cfun)->next_bb;


#if RUNTIME_ARG_CHECK == 1
    struct argument_count c;
    get_argument_count(fndef, &c);
    uint32_t call_nop_imm = (1 << 1) | (c.count << 2) | (c.is_variadic << 10);
#if DEBUG >= 1
    fprintf(stderr, "Function %s uses %d arguments it is%s variadic\n", IDENTIFIER_POINTER(DECL_NAME(fndef)), c.count, c.is_variadic ? "" : " not");
#endif
#else
    uint32_t call_nop_imm = (1 << 1);
#endif

#if DEBUG >= 1
    fprintf(stderr, "[function start] adding nop %s\n", LI_ZERO(call_nop_imm));
#endif

#if DEBUG == 2
    print_rtl_single(stderr, BB_HEAD(entry));
#endif

    // insert nop at the beginning of the function

#if RUNTIME_CALL_ANNOTATION == 1
    insert_asm(BB_HEAD(entry), LI_ZERO(call_nop_imm));
#endif

    // insert nop after each call instruction
    rtx_insn *ins = BB_HEAD(entry);
    while (ins)
    {

        if (GET_CODE(ins) == CALL_INSN)
        {

#if RUNTIME_ARG_CHECK == 1
            bool is_indirect = is_indirect_call(ins);
            if (is_indirect)
            {
#if DEBUG >= 1
                fprintf(stderr, "Indirect call: prefixing with %s\n", CSRWI_3FE(count_call_ins_arguments(ins)));
#endif
                insert_asm(ins, CSRWI_3FE(count_call_ins_arguments(ins)), true);
            }
#endif

#if RUNTIME_RET_ANNOTATION == 1

#if DEBUG >= 1
            fprintf(stderr, "[call instruction] adding nop %s: \n", LI_ZERO(1));
#endif

#if DEBUG == 2
            print_rtl_single(stderr, ins);
#endif

            insert_asm(ins, LI_ZERO(1));
#endif
        }

        ins = next_insn(ins);
    }

    // when DEBUGging, shows the rtl outputted
#if DEBUG == 2
    fprintf(stderr, "\n> --------------------- \n> - RTL AFTER \n> --------------------- \n\n");
    print_rtl(stderr, BB_HEAD(entry));
#endif
    return 0;
}

/**
 * Metadata for a pass, non-varying across all instances of a pass
 * @see Declared in tree-pass.h
 * @note Refer to tree-pass for docs about
 */
struct pass_data ins_pass_data =
    {
        .type = RTL_PASS,               // type of pass
        .name = PLUGIN_NAME,            // name of plugin
        .optinfo_flags = OPTGROUP_NONE, // no opt dump
        .tv_id = TV_NONE,               // no timevar (see timevar.h)
        .properties_required = 0,       // no prop in input
        .properties_provided = 0,       // no prop in output
        .properties_destroyed = 0,      // no prop removed
        .todo_flags_start = 0,          // need nothing before
        .todo_flags_finish = 0          // need nothing after
};

/**
 * Definition of our instrumentation RTL pass
 * @note Extends rtl_opt_pass class
 * @see Declared in tree-pass.h
 */
class ins_rtl_pass : public rtl_opt_pass
{
public:
    /**
     * Constructor
     */
    ins_rtl_pass(const pass_data &data, gcc::context *ctxt) : rtl_opt_pass(data, ctxt) {}

    /**
     * This and all sub-passes are executed only if the function returns true
     * @note Defined in opt_pass father class
     * @see Defined in tree-pass.h
     */
    bool gate(function *gate_fun)
    {
        return true;
    }

    /**
     * This is the code to run when pass is executed
     * @note Defined in opt_pass father class
     * @see Defined in tree-pass.h
     */
    unsigned int execute(function *exec_fun)
    {
        return instrument_assignments_plugin_exec();
    }
};

// instanciate a new instrumentation RTL pass
ins_rtl_pass inst_pass = ins_rtl_pass(ins_pass_data, g);

// -----------------------------------------------------------------------------
// PLUGIN INITIALIZATION
// -----------------------------------------------------------------------------

/**
 * Initializes the plugin. Returns 0 if initialization finishes successfully.
 */
int plugin_init(struct plugin_name_args *info, struct plugin_gcc_version *ver)
{
    // new pass that will be registered
    struct register_pass_info pass;

    // this plugin is compatible only with specified base ver
    if (strncmp(inst_plugin_ver.basever, ver->basever, strlen(ver->basever)))
        return 1;

    // tell to GCC some info about this plugin
    register_callback(PLUGIN_NAME, PLUGIN_INFO, NULL, &inst_plugin_info);

    // warn the user about the presence of this plugin
#if DEBUG == 2
    printf("> Instrumentation plugin '%s @ %s' was loaded onto GCC\n", PLUGIN_NAME, PLUGIN_VERSION);
#endif
    // insert inst pass into the struct used to register the pass
    pass.pass = &inst_pass;

    // get called after Control flow graph cleanup (see RTL passes)
    // see https://gcc.gnu.org/onlinedocs/gccint/RTL-passes.html and https://github.com/gcc-mirror/gcc/blob/master/gcc/passes.def
    // For reference Intel CET passe "pass_insert_endbranch" is inserted just after pass "pass_convert_to_eh_region_ranges"
    pass.reference_pass_name = "eh_ranges";

    // after the first opt pass to be sure opt will not throw away our stuff
    pass.ref_pass_instance_number = 1;
    pass.pos_op = PASS_POS_INSERT_AFTER;

    // add our pass hooking into pass manager
    register_callback(PLUGIN_NAME, PLUGIN_PASS_MANAGER_SETUP, NULL, &pass);

    // everthing has worked
    return 0;
}
