require_relative "./error.rb"

def infer(root)
  # todo for the ops that actually exist, is empty untyped array actually ok (to not know its dimension??)
  trace_type(root)
  root
end

def trace_type(node)
  return node.type if node.type
  arg_types = nil
  impl_fn,type_fn,static_fn,type_checker_fn = node.op.behavior[node.op.token]
  node.type = Promise.new{
    # special case for zipped reads

    manual_zips = if is_special_zip(node.op.str)
      0
    else
      node.op.str[/^!*/].size
    end
    min_dims,possible_zips,auto_zips,*err_fn=static_fn[*arg_types]
    min_dims = min_dims.map{|i|[0,i].max}

    # have them specify possible zips rather than calculate because some things like if/else wouldn't make sense to zip replicating first, so disable it manually (alternatively could calcuate max dim dynamically)

    raise AtlasTypeError.new "cant manual zip any more dims",node.op.token if manual_zips > possible_zips.to_i
    zip_level = auto_zips.to_i + manual_zips

    # bring negative dims up to scalar dim (e.g. for trinary)
    reps = min_dims.zip(arg_types).map{|r,t|
      Promise.new{
        r=[zip_level.to_i-t.value.to_i+r.to_i,0].max

        # generally can't happen because max pos zip level is set
        # What should it do if we wanted to allow it?
        if r.to_i > zip_level
          raise AtlasTypeError.new('rep level exceeds zip level %d %d' % [r.to_i,zip_level],node.op.token)
        end
        r
      }
    }

    modified_dims = reps.zip(arg_types).map{|r,t|
      Promise.new{t.value + (r.value.to_i - zip_level.to_i)}}

    node.impl = Promise.new{
      args = node.args.map{|t|t.impl}
      args = reps.zip(args).map{|r,v|
        repn(r.value,v)
      }
      zipn(zip_level, args, impl_fn[*modified_dims])
    }

    type_fn[*modified_dims]+zip_level
  }
  # infer all types, even if not used by type fn (for code gen/etc)
  arg_types = node.args.map{|t|trace_type(t)}
  node.type
end

class AST
  attr_accessor :type
  attr_accessor :impl
end