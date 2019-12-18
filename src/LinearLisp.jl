module LinearLisp

using Tokenize

abstract type Binding end

struct ValueBinding <: Binding
    name
    value  # Julia literal
end

value(binding::ValueBinding) = binding.value

struct FunctionBinding <: Binding
    name
    params
    scope
    arity
    body  # tokens
end

params(binding::FunctionBinding) = binding.params
scope(binding::FunctionBinding) = binding.scope
arity(binding::FunctionBinding) = binding.arity
body(binding::FunctionBinding) = binding.body

function FunctionBinding(name, parent_scope, expr)
    FunctionBinding(
        name, params, empty_scope(parent_scope), expr.arity, expr.body)
end

struct FunctionExpr
    params
    arity
    body
end

struct SyntaxBinding <: Binding
    name
    form  # tokens
end

struct PrimitiveBinding <: Binding
    name
    handler  # Julia function
end

handler(binding::PrimitiveBinding) = binding.handler

struct Scope
    bindings  # mapping Symbol to Binding
    parent  # nothing or next scope to search for binding.
end

name(binding::Binding) = binding.name

function bind!(scope::Scope, binding_name, value)
    # @show binding_name value
    if value isa FunctionExpr
        binding = FunctionBinding(binding_name, scope, value)
    elseif value isa Binding
        binding = value
    else
        binding = ValueBinding(binding_name, value)
    end
    setindex!(scope.bindings, value, binding_name)
    scope
end
function get(scope::Scope, name::Symbol)
    scope.bindings[name]
end
function get(scope::Scope, name::Union{Number,String})
    name
end

empty_scope(parent=nothing) = load_primitives!(Scope(
    Dict{Symbol,Any}(),
    parent,
))

function load_primitives!(scope)
    bind!(scope, :def, PrimitiveBinding(:def, handle_def!))
    bind!(scope, :fn, PrimitiveBinding(:fn, handle_fn!))
    bind!(scope, :syntax, PrimitiveBinding(:syntax, handle_syntax!))
end

function handle_def!(scope, L)
    # expected L = [:def, name, value, ...]
    @show scope L
    name = L[2]
    restL = @view L[3:end]
    @show restL
    value, newL = eval_binding(scope, restL)
    bind!(scope, name, value), newL
end

function handle_fn!(scope, L)
    @show scope L
end

function handle_syntax!(scope, L)
    @show scope L
end

function eval_binding(scope, L)
    @show scope L
    binding = get(scope, L[1])
    @show binding
    if binding isa PrimitiveBinding
        @show "PrimitiveBinding"
        binding_value, newL = handler(binding)(scope, L)
    elseif binding isa FunctionBinding
        @show "FunctionBinding"
        args, newL = eval_function_args(scope, arity(binding), @view L[2:end])
        fn_scope = scope(binding)
        for (p, a) in zip(params(binding), args)
            bind!(fn_scope, p, a)
        end
        binding_value, _ = eval_binding(fn_scope, body(binding))
    elseif binding isa SyntaxBinding
        @show "SyntaxBinding"
        L = binding(scope, L)
        binding_value, newL = eval_binding(scope, L)
    elseif binding isa ValueBinding
        @show "ValueBinding"
        binding_value, newL = value(binding), @view L[2:end]
    else  # literal value
        @show "Literal"
        binding_value, newL = binding, @view L[2:end]
    end
    binding_value, newL
end

function eval_function_args(scope, arity, L)
    @show scope arity L
end

const IDENTIFIER = Tokenize.Tokens.IDENTIFIER
const WHITESPACE = Tokenize.Tokens.WHITESPACE
const STRING = Tokenize.Tokens.STRING
const INTEGER = Tokenize.Tokens.INTEGER
const FLOAT = Tokenize.Tokens.FLOAT
const KEYWORD = Tokenize.Tokens.KEYWORD
const SEMICOLON = Tokenize.Tokens.SEMICOLON

const DEF_ID = Symbol("def")

const LAMBDA_ID = Symbol("lambda")
const LAMBDA_BODY_START_ID = Symbol("do")
const LAMBDA_BODY_END_ID = Symbol("end")

const DEFUN_ID = Symbol("defun")
const DEFUN_END_ID = Symbol("close")
kind(t) = Tokenize.Tokens.kind(t)
untokenize(t) = Tokenize.Tokens.untokenize(t)
null_lexpr(L) = length(L) == 0
isliteral(t) = kind(t) === STRING || kind(t) === INTEGER || kind(t) === FLOAT

parse_lexpr(source) = collect(tokenize(source))

function make_lexpr(source)
    expr = []
    for t in parse_lexpr(source)
        kind(t) === WHITESPACE && continue
        if kind(t) === IDENTIFIER || kind(t) === KEYWORD
            push!(expr, Symbol(untokenize(t)))
        elseif isliteral(t)
            push!(expr, untokenize(t))
        end
    end
    expr
end

end # module
