#!/usr/bin/julia -f
# Copyright (c) 2016-2016, Yichao Yu <yyc1992@gmail.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 3.0 of the License, or (at your option) any later version.
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
# You should have received a copy of the GNU Lesser General Public
# License along with this library.

module Channels

# None of the fields should be mutated after construction
immutable Node
    name::String
    # This can probably also be a `Dict{Node,Node}`
    # with proper `hash` and `isequal`
    children::Dict{String,Node}
    parent::Node
    # Root node
    Node() = new("", Dict{String,Node}())
    # Normal node
    function Node(name, parent::Node)
        self = new(name, Dict{String,Node}(), parent)
        parent.children[name] = self
        return self
    end
end

@inline is_root(node::Node) = !isdefined(node, :parent)

function get_path(node::Node)
    # Check root first so that the `parent` access below don't need
    # NULL check
    is_root(node) && return String[]
    # This should not form a loop.
    parent_path = get_path(node.parent)
    return push!(parent_path, node.name)
end

function show_link(io::IO, child::Node)
    print(io, " -> [")
    link_path = get_path(child)
    first = true
    for name in get_path(child)
        if !first
            print(io, ", ")
        end
        first = false
        show(io, name)
    end
    print(io, "]")
    return
end

function Base.show(io::IO, node::Node)
    if is_root(node)
        print(io, "Node(children=[")
    else
        parent = node.parent
        print(io, "Node(name=")
        show(io, node.name)
        print(io, ", parent=")
        if is_root(parent)
            print(io, "root")
        else
            show(io, parent.name)
        end
        print(io, ", children=[")
    end
    first = true
    for (name, child) in node.children
        if !first
            print(io, ", ")
        end
        first = false
        show(io, name)
        if name != child.name
            show_link(io, child)
        end
    end
    print(io, "])")
    return
end

function Base.getindex(root::Node, path::AbstractVector)
    node = root
    for name in path
        children = node.children
        if name in keys(children)
            node = children[name]
        else
            node = children[name] = Node(name, node)
        end
    end
    return node
end

function Base.getindex(root::Node, name::String)
    children = root.children
    if name in keys(children)
        return children[name]
    else
        return children[name] = Node(name, root)
    end
end

_to_node(root::Node, node::Node) = node
_to_node(root::Node, node) = root[node]

function Base.setindex!(root::Node, src, dest::AbstractVector)
    dest_parent_node = root[@view dest[1:(end - 1)]]
    children = dest_parent_node.children
    name = dest[end]
    if name in keys(children)
        throw(ArgumentError("Overwriting existing channel"))
    end
    return children[name] = _to_node(root, src)
end

end
