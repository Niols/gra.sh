################################################################################
##                                                   .__                      ##
##                   ____ _______ _____        ______|  |__                   ##
##                  / ___\\_  __ \\__  \      /  ___/|  |  \                  ##
##                 / /_/  >|  | \/ / __ \_ __ \___ \ |   Y  \                 ##
##                 \___  / |__|   (____  //_//____  >|___|  /                 ##
##                /_____/              \/         \/      \/                  ##
##                                                                            ##
##                         Because we like it dirty.                          ##
##                                                                            ##
##                                                                            ##
##  <niols@niols.fr> wrote this file. As long as you retain this notice you    ##
##  can do whatever you want with this stuff. If we meet some day, and you     ##
##  think this stuff is worth it, you can buy me a beer in return.             ##
##                                                                            ##
################################################################################


## utils

function list { ls --color=never -1 "$@"; }

function is_symbolic_link { [ -L "$1" ]; }
function is_empty         { [ -z "$1" ]; }
function is_directory     { [ -d "$1" ]; }
function is_regular_file   { [ -f "$1" ]; }


## gra.sh

function create_graph # string -> graph
{
    local name=$1; shift

    local graph="$(mktemp -d)/$name"
    mkdir "$graph"
    echo -n "$graph"
}

function delete_graph # graph -> unit
{
    local graph=$1; shift

    rm -r "$graph"
}

function get_name # graph -> string
{
    local graph=$1; shift

    list "$graph/.."
}

function load_graph # path -> graph
{
    path=$1; shift

    local tmpdir=$(mktemp -d)
    tar xzf "$path" -C "$tmpdir"
    echo -n "$tmpdir/$(ls -1 \"$tmpdir\")"
}

function save_graph # graph -> path -> unit
{
    local graph=$1; shift
    local path=$1;  shift

    local name=$(get_name "$graph")
    tar czf "$path" -C "$graph/.." "$name"
}

function copy_graph # graph -> string -> graph
{
    local graph=$1; shift
    local name=$1;  shift

    local new_graph=$(create_graph "$name")
    cp -r "$graph" "$new_graph"
    echo -n "$new_graph"
}

function get_property # graph -> key -> value
{
    local graph=$1;    shift
    local property=$1; shift

    cat "$graph/.$property"
}

function set_property # graph -> key -> value -> unit
{
    local graph=$1;    shift
    local property=$1; shift
    local content=$1;  shift

    echo -n "$content" > "$graph/.$property"
}

function add_node # graph -> string -> unit
{
    local graph=$1; shift
    local name=$1;  shift

    mkdir "$graph/$name"
}

function del_node # graph -> node -> unit
{
    local graph=$1; shift
    local node=$1;  shift

    rmdir "$graph/$name"
}

function has_node # graph -> node -> bool
{
    local graph=$1; shift
    local node=$1;  shift

    is_directory "$graph/$node"
}

function get_nodes # graph -> node list
{
    local graph=$1; shift

    list "$graph"
}

function get_node_property # graph -> node -> key -> value
{
    local graph=$1;    shift
    local node=$1;     shift
    local property=$1; shift

    cat "$graph/$node/.$property"
}

function set_node_property # graph -> node -> key -> value -> unit
{
    local graph=$1;    shift
    local node=$1;     shift
    local property=$1; shift
    local content=$1;  shift

    echo -n "$content" > "$graph/$node/.$property"
}

function has_node_property # graph -> node -> key -> bool
{
    local graph=$1;    shift
    local node=$1;     shift
    local property=$1; shift

    is_regular_file "$graph/$node/.$property"
}

function add_neighbor # graph -> node -> node -> unit
{
    local graph=$1; shift
    local node1=$1; shift
    local node2=$1; shift

    ln -s "../$node2" "$graph/$node1/$node2"
}

function del_neighbor # graph -> node -> node -> unit
{
    local graph=$1; shift
    local node1=$1; shift
    local node2=$1; shift

    rm "$graph/$node1/$node2"
}

function has_neighbor # graph -> node -> node -> bool
{
    local graph=$1; shift
    local node1=$1; shift
    local node2=$1; shift

    is_symbolic_link "$graph/$node1/$node2"
}

function get_neighbors # graph -> node -> node list
{
    local graph=$1; shift
    local node=$1;  shift

    list "$graph/$node"
}


## Aliases

function make_graph   { create_graph "$@"; }
function remove_graph { delete_graph "$@"; }
function add_edge     { add_neighbor "$@"; }
function del_edge     { del_neighbor "$@"; }
function has_edge     { has_neighbor "$@"; }


## Higher-order functions

function complete # graph -> unit
{
    local graph=$1; shift
    local node1
    local node2

    get_nodes $graph | while read node1
    do
	get_nodes $graph | while read node2
	do
	    add_edge $graph $node1 $node2
	done
    done
}

function to_dot # graph -> string
{
    local graph=$1; shift
    local node
    local node1
    local node2

    echo "digraph $(get_name $graph) {"

    get_nodes $graph | while read node
    do
	echo "  $node"
    done

    get_nodes $graph | while read node1
    do
	get_nodes $graph | while read node2
	do
	    if has_edge $graph $node1 $node2
	    then
		echo "  $node1 -> $node2"
	    fi
	done
    done

    echo '}'
}

function _hamiltonian_path_aux # graph -> node list -> node list
{
    local graph=$1; shift
    local nodes=$1; shift

    local node
    local last
    local nexts
    local first
    local legal_nexts
    local next

    last=$(echo "$nodes" | tail -n 1)

    nexts=$(get_neighbors "$graph" "$last")

    if [ `echo "$nodes" | wc -l` -eq `get_nodes "$graph" | wc -l` ]
    then
	## Case were the path has the same length as the graph.
	## We just check if we can reach the first node.

	first=$(echo "$nodes" | head -n 1)

	if echo "$nexts" | grep -q "^$first$"
	then
	    echo "$nodes"
	    return 0
	else
	    return 1
	fi

    else
	## We just try all the other nodes that we can reach
	## without breaking the hamiltonian path rule.

	legal_nexts=$(comm -23 <(echo "$nexts" | sort) <(echo "$nodes" | sort))

	is_empty "$legal_nexts" && return 1

	## Since the while is at the right of a pipe, it is running in a
	## subshell. Hence, the return statement isn't interupting the function
	## but only this subshell.
	## This is why we had to put a return 1 in the subshell and not after,
	## and this is why we have to return $? at the end.

	echo "$legal_nexts" \
	    | sort -R \
	    | (while read next
	       do
		   if _hamiltonian_path_aux "$graph" `echo -e "$nodes\n$next"`
		   then
		       return 0
		   fi
	       done
	       return 1)

	return "$?"
    fi
}
function hamiltonian_path # graph -> node list
{
    local graph=$1; shift
    _hamiltonian_path_aux "$graph" `get_nodes "$graph" | head -n 1`
}
