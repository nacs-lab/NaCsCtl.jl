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
type Node
    name::String
    # This can probably also be a `Dict{Node,Node}`
    # with proper `hash` and `isequal`
    children::Dict{String,Node}
    parent_or_link::Node
    # Root node
    Node(name) = new(name, Dict{String,Node}())
    # Normal mode
    function Node(name, islink::Bool, parent_or_link::Node)
        if islink
            self = new(name)
        else
            self = Node(name)
        end
        self.parent_or_link = parent_or_link
        return self
    end
end

@inline is_link(node::Node) = !isdefined(node, :children)
@inline is_root(node::Node) = !isdefined(node, :parent_or_link)

function get_path(node::Node)
    # Check root first so that the `parent_or_link` access below don't need
    # NULL check
    is_root(node) && return [node.name]
    # This should not form a loop.
    parent_or_link_path = get_path(node.parent_or_link)
    is_link(node) && return parent_or_link_path
    push!(parent_or_link_path, node.name)
    return parent_or_link_path
end

end
