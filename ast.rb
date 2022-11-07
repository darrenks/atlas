AST=Struct.new(:op,:args,:type,:zip_level,:promise,:expected_type)

# module Status
#   UNSEEN = 1 # in practice nil will be used
#   PROCESSING = 2
#   SEEN = 3
# end
#
# def dfs(root,cycle_fn:,post_fn:)
#   enumerate_nodes(root,0) if !root.id
#   dfs_helper(root,[],cycle_fn,post_fn)
# end
#
# def dfs_helper(node,been,cycle_fn,post_fn)
#   if been[node.id] == Status::SEEN
#
#   elsif been[node.id] == Status::PROCESSING # cycle
#     cycle_fn[node]
#   else
#     been[node.id] = Status::PROCESSING
#     node.args.each{|arg|
#       dfs_helper(arg,been,cycle_fn,post_fn)
#     }
#     post_fn[node]
#   end
#   been[node.id] = Status::SEEN
#   return
# end
#
# def enumerate_nodes(node,count)
#   return if node.id
#   node.id = count
#   node.args.each{|arg|
#     count=enumerate_nodes(arg,count+1)
#   }
#   count
# end