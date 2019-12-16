module LL

using Tokenize

const IDENTIFIER = Tokenize.Tokens.IDENTIFIER
const WHITESPACE = Tokenize.Tokens.WHITESPACE
const STRING = Tokenize.Tokens.STRING
const INTEGER = Tokenize.Tokens.INTEGER
const FLOAT = Tokenize.Tokens.FLOAT
const DEF_ID = Symbol("def")
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
        if kind(t) === IDENTIFIER
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

baremodule Primitives

import Base
import ..LL

function eval(L)
    LL.eval_lexpr(L)
end

function print(L)
    Base.println("My print")
    L = eval(L)
    Base.println(L[1])
    L[2:end]
end

end

end # module
