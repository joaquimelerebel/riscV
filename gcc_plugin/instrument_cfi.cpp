/**
 * A gcc plugin that add instructions needed for CFI
 * Heavily based on the blog post of Grabiele Serra :
 * https://gabrieleserra.ml/blog/2020-08-27-an-introduction-to-gcc-and-gccs-plugins.html
*/

#include <gcc-plugin.h>
#include <rtl.h>
#include <target.h>
#include <tree.h>
#include <tree-pass.h>
#include <stringpool.h>
#include <attribs.h>
#include <memmodel.h>
#include <emit-rtl.h>

/**
 * When 1 enables verbose printing
 */
#define DEBUG               1

/**
 * Name of this plugin
 */
#define PLUGIN_NAME         "inst_plugin_cfi"

/**
 * Version of this plugin
 */
#define PLUGIN_VERSION      "0.1"

/**
 * Help/usage string for the plugin
 */
#define PLUGIN_HELP         "Usage: just do it"

/**
 * Required GCC version
 */
#define PLUGIN_GCC_BASEV    "12.1.0"

// -----------------------------------------------------------------------------
// GCC PLUGIN SETUP (BASIC INFO / LICENSE / REQUIRED VERSION)
// -----------------------------------------------------------------------------

int plugin_is_GPL_compatible;

/**
 * Additional information about the plugin. Used by --help and --version
 */
static struct plugin_info inst_plugin_info =
{
  .version  = PLUGIN_VERSION,
  .help     = PLUGIN_HELP,
};

/**
 * Represents the gcc version we need. Used to void using an incompatible plugin 
 */
static struct plugin_gcc_version inst_plugin_ver =
{
  .basever  = PLUGIN_GCC_BASEV,
};

// -----------------------------------------------------------------------------
// GCC EXTERNAL DECLARATION
// -----------------------------------------------------------------------------

/**
 * Takes a tree node and returns the identifier string
 * @see https://gcc.gnu.org/onlinedocs/gccint/Identifiers.html
 */
#define FN_NAME(tree_fun) IDENTIFIER_POINTER (DECL_NAME (tree_fun))

/**
 * Takes a tree node and returns the identifier string length
 * @see https://gcc.gnu.org/onlinedocs/gccint/Identifiers.html
 */
#define FN_NAME_LEN(tree_fun) IDENTIFIER_LENGTH (DECL_NAME (tree_fun))

/**
 * Print GIMPLE statement G to FILE using SPC indentation spaces and FLAGS
 * @note Makes use of pp_gimple_stmt_1
 * @see Declared in gimple-pretty-print.h
 * @see Flags are listed in dumpfile.h
 */
extern void print_gimple_stmt(FILE * file, gimple* g, int spc, dump_flags_t flags);

/**
 * Print tree T, and its successors, on file FILE. FLAGS specifies details to 
 * show in the dump
 * @note Makes use of dump_generic_node
 * @see Declared in tree-pretty-print.h
 * @see Flags are listed in dumpfile.h
 */
extern void print_generic_stmt(FILE* file, tree t, dump_flags_t flags);

/** 
 * The global singleton context aka "g". The name is chosen to be easy to type
 * in a debugger. Represents the 'global state' of GCC
 * 
 * GCC's internal state can be divided into zero or more "parallel universe" of 
 * state; an instance of the class context is one such context of state
 * 
 * @see Declared in context.h
 */
extern gcc::context *g;

// -----------------------------------------------------------------------------
// GCC ATTRIBUTES MANAGEMENT (REGISTERING / CALLBACKS)
// -----------------------------------------------------------------------------

/**
 * Insert a single ATTR into the attribute table
 * @see Declared in plugin.h
 * @note Insert the attribute into the 'gnu' attributes namespace
 */
extern void register_attribute(const struct attribute_spec *attr);

/**
 * Attribute handler callback 
 * @note NODE points to the node to which the attribute is to be applied. NAME 
 * is the name of the attribute. ARGS is the TREE_LIST of arguments (may be 
 * NULL). FLAGS gives information about the context of the attribute. 
 * Afterwards, the attributes will be added unless *NO_ADD_ATTRS is set to true 
 * (which should be done on error). Depending on FLAGS, any attributes to be 
 * applied to another type or DECL later may be returned; otherwise the return 
 * value should be NULL_TREE. This pointer may be NULL if no special handling is
 * required
 * @see Declared in tree-core.h
 */
static tree handle_instrument_attribute(tree *node, tree name, tree args, int flags, bool *no_add_attrs)
{
    #if DEBUG == 1
        fprintf(stderr, "> Found attribute\n");

        fprintf(stderr, "\tnode = ");
        print_generic_stmt(stderr, *node, TDF_NONE);
        
        fprintf(stderr, "\tname = ");
        print_generic_stmt(stderr, name, TDF_NONE);
    #endif

    return NULL_TREE;
}

// -----------------------------------------------------------------------------
// PLUGIN INSTRUMENTATION LOGICS
// -----------------------------------------------------------------------------

/**
 * Take a basic block as input and seek the insn list until the function prologue
 */
rtx_insn* seek_till_fn_prologue(basic_block bb)
{
    rtx_insn *tmp_rtx;
    
    for (tmp_rtx = BB_HEAD(bb); tmp_rtx != 0; tmp_rtx = NEXT_INSN (tmp_rtx))
	{
        if ( (GET_CODE(tmp_rtx) == NOTE) && (NOTE_KIND (tmp_rtx) == NOTE_INSN_FUNCTION_BEG))
            break;
    }

    return tmp_rtx;
}

/**
 * Create a nop instruction and insert it after the given stmt
 */

static void insert_nop(rtx_insn * loc)
{
    char opcode[] = "add x0, x0, 1";
    tree string = build_string(strlen(opcode), opcode);
    
    rtx body = gen_rtx_ASM_INPUT_loc (VOIDmode, ggc_strdup (TREE_STRING_POINTER (string)), INSN_LOCATION (loc));
    emit_insn_after_setloc (body, loc, INSN_LOCATION(loc));
}

/**
 * For each function lookup attributes and attach profiling function
 */
static unsigned int instrument_assignments_plugin_exec(void)
{
    // get the FUNCTION_DECL of the function whose body we are reading
    tree fndef = current_function_decl;
    
    // print the function name
    int debug = strncmp(FN_NAME(fndef), "k_work_delayable_busy_get", FN_NAME_LEN(fndef)) == 0 ? 1 : 0;
    fprintf(stderr, "> Inspecting function '%s' %d\n", FN_NAME(fndef), debug);

    // get function entry block
    basic_block entry = ENTRY_BLOCK_PTR_FOR_FN(cfun)->next_bb;

    // warn the user we are adding a profiling function
    if(debug){
        fprintf(stderr, "\t [function start] adding nop after RTL: ");
        print_rtl_single(stderr, BB_HEAD(entry));
    }
    
    // insert nop at the beginning of the function
    // insert_nop(BB_HEAD(entry));

    // insert nop after each call instruction
    rtx_insn* ins = BB_HEAD(entry);
    while(ins){
        if(GET_CODE(ins) == CALL_INSN){
            if(debug){
                fprintf(stderr, "\t [call instruction] adding nop after RTL: ");
                print_rtl_single(stderr, ins);
            }
            insert_nop(ins);
        }
        ins = next_insn(ins);
    }

    // when debugging, shows the rtl outputted
    if(debug){
        fprintf(stderr, "\n> --------------------- \n> - RTL AFTER \n> --------------------- \n\n");
        print_rtl(stderr, BB_HEAD(entry));
    }
    return 0;
}

/** 
 * Metadata for a pass, non-varying across all instances of a pass
 * @see Declared in tree-pass.h
 * @note Refer to tree-pass for docs about
 */
struct pass_data ins_pass_data =
{
    .type = RTL_PASS,                                       // type of pass
    .name = PLUGIN_NAME,                                    // name of plugin
    .optinfo_flags = OPTGROUP_NONE,                         // no opt dump
    .tv_id = TV_NONE,                                       // no timevar (see timevar.h)
    .properties_required = 0,                               // no prop in input
    .properties_provided = 0,                               // no prop in output
    .properties_destroyed = 0,                              // no prop removed
    .todo_flags_start = 0,                                  // need nothing before
    .todo_flags_finish = 0                                  // need nothing after
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
    ins_rtl_pass (const pass_data& data, gcc::context *ctxt) : rtl_opt_pass (data, ctxt) {}

    /**
     * This and all sub-passes are executed only if the function returns true
     * @note Defined in opt_pass father class
     * @see Defined in tree-pass.h
     */ 
    bool gate (function* gate_fun) 
    {
        return true;
    }

    /**
     * This is the code to run when pass is executed
     * @note Defined in opt_pass father class
     * @see Defined in tree-pass.h
     */
    unsigned int execute(function* exec_fun)
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
    printf("> Instrumentation plugin '%s @ %s' was loaded onto GCC\n", PLUGIN_NAME, PLUGIN_VERSION);

    // insert inst pass into the struct used to register the pass
    pass.pass = &inst_pass;

    // get called after Control flow graph cleanup (see RTL passes)  
    pass.reference_pass_name = "*free_cfg";

    // after the first opt pass to be sure opt will not throw away our stuff
    pass.ref_pass_instance_number = 1;
    pass.pos_op = PASS_POS_INSERT_AFTER;

    // add our pass hooking into pass manager
    register_callback(PLUGIN_NAME, PLUGIN_PASS_MANAGER_SETUP, NULL, &pass);

    // everthing has worked
    return 0;
}
