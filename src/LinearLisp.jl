module LinearLisp

using Tokenize

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

function eval_lexpr(L)
    null_lexpr(L) && return L
    atom = L[1]
    if atom === DEF_ID
        if length(L) < 3
            println("Invalid def expression at")
            println(t)
            return []
        end
        let target = L[2], value = L[3]
            @eval Primitives begin
                $(target) = $(value)
            end
        end
        L[4:end]
    elseif atom === DEFUN_ID
        close_i = findnext(x -> x == LL.DEFUN_END_ID, L, 1)
        let name = L[2], param = L[3], body = L[4:close_i-1]
            @eval Primitives begin
                function $(name)($(param))
                    @show $(body)
                    $(program)($(body), true)
                end
            end
        end
        return L[close_i+1:end]
    else
        value = Base.eval(Primitives, atom)
        if value isa String
            return [value; L[2:end]]
        else
            # @show value L[2:end]
            return value(L[2:end])
        end
    end
end

function program(L, quiet=False)
    while !null_lexpr(L)
        # @show L
        L = let new_L = eval_lexpr(L)
            # @show new_L
            if length(new_L) == length(L)
                println(new_L[1])
                new_L = new_L[2:end]
            end
            new_L
        end
    end
end

# recursively expand tokens into Julia expressions for evaluation.
function expand_all(L)
    L = copy(L)
    expanded_expr = []
    while length(L) > 0
        @show L expanded_expr
        expr, L = expand(L)
        push!(expanded_expr, expr)
        # DEBUG infinit loop
        # if length(expanded_expr) > 4
        #     break
        # end
    end
    expanded_expr
end

function expand(L)
    token = L[1]
    if token isa String
        expr = Meta.parse(L[1])
        L = L[2:end]
    elseif token in keys(SYNTAX)
        handler = SYNTAX[token]
        expr, L = handler(L)
    else
        # TODO: expand function calls.
        @show token "Unhandled function call or variable lookup."
        expr, L = L[1], L[2:end]
    end
    expr, L
end

# primitive forms
#
# We should first expand the tokens into primitive forms and then emit code.
# This allows us to track important information like function arity that's
# not convenient to track in Julia.
struct DefExpr
    target
    value # Expr
    code
end

struct LambdaExpr
    params
    body # Expr
    code
end

arity(expr::LambdaExpr) = length(expr.params)

# primitive syntax
#
# converts L expressions into Julia expressions.
function emit_def(L)
    # L[1] is keyword def, we skip
    target = L[2]
    value, L = expand(L[3:end])
    code = :($(target) = $(value))
    DefExpr(target, value, code), L
end

function emit_lambda_named_args(L)
    # L[1] is keyword lambda, we skip.
    # until do determines what if any parameters the lambda has.
    i = findnext(x -> x === LAMBDA_BODY_START_ID, L, 1)
    params = L[2:i-1]
    j = findnext(x -> x === LAMBDA_BODY_END_ID, L, i)
    body = L[i+1:j-1]
    # TODO: eval body for syntax and convert to primitves.
    @show params body
    code = Expr(:->, Expr(:tuple, params...), Expr(:block, body...))
    return LambdaExpr(params, body, code), L[j+1:end]
end

function emit_function_call(L)
    @show L
end

# TODO: Find better way to track arity directly.
function arity(lambda)
    return length(first(methods(lambda)).sig.parameters) - 1
end


# syntax map to determine how to emit Julia from the Token stream.
SYNTAX = Dict{Symbol, Any}([
    DEF_ID => emit_def,
    LAMBDA_ID => emit_lambda_named_args
])

# Store arity of functions to enable parsing.
# TODO: Avoid a global symbol table.
FUNCTIONS = Dict{Symbol, Int}()


baremodule Primitives

import Base
import ..LL

function print(L)
    Base.println("My print")
    L = eval(L)
    Base.println(L[1])
    L[2:end]
end

function eval(L)
    LL.eval_lexpr(L)
end

end

end # module
