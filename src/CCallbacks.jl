module CCallbacks

function parse_cargs(arg_spec,arg_sel,do_escape)    
    ret_type = arg_spec.args[2]
    cargs = arg_spec.args[1].args[arg_sel]

    arg_names = []
    arg_types = []
    
    for carg in cargs
        carg.head == :(::) || error("Invalid argument specification $(carg)")
        push!(arg_names, do_escape ? :($(esc(carg.args[1]))) : :($(carg.args[1])))
        push!(arg_types, carg.args[2])
    end

    arg_names,arg_types,ret_type
end

# Stolen from https://gist.github.com/simonbyrne/c4146dc286fd5387385ca911e8318509
@eval macro $(Symbol("ccall"))(expr)
    expr.head == :(::) && expr.args[1].head == :call || error("Invalid use of @ccall")
    
    arg_names,arg_types,ret_type = parse_cargs(expr, 2:lastindex(expr.args[1].args), true)
    fname = expr.args[1].args[1]

    tupexpr = :(())
    ccexpr = :(ccall($(esc(fname)), $(esc(ret_type)), $(esc(tupexpr))))
    append!(ccexpr.args, arg_names)
    append!(tupexpr.args, arg_types)

    ccexpr
end

macro ccallback(arg_spec, body)
    arg_spec.head == :(::) && arg_spec.args[1].head == :tuple ||
        error("Invalid argument specification")
    body.head == :block || error("Callback block missing")
    
    arg_names,arg_types,ret_type = parse_cargs(arg_spec, :, false)

    # TODO: Need to figure out how to escape variable references in
    # the body block.
    local ccallback_expr = :(() -> $(body))
    ccallback_expr.args[1].args = arg_names
    # For convenience, such that we don't have to remember to put
    # nothing:s at the end of all callbacks declared Cvoid.
    ret_type == :Cvoid && push!(ccallback_expr.args[2].args[2].args, nothing)

    cfun = Expr(:cfunction, Ptr{Cvoid},
                QuoteNode(ccallback_expr),
                ret_type,
                Expr(:call, GlobalRef(Core, :svec), arg_types...),
                QuoteNode(:ccall))
    esc(cfun)
end

export @ccall, @ccallback

end # module
