module Riak
  module Crdt

    # A distributed map of multiple fields, such as counters, flags, registers,
    # sets, and, recursively, other maps, using the Riak 2 Data Types feature.
    #
    # Maps are complex, and the implementation is spread across many classes.
    # You're looking at the top-level {Map} class, but there are also others
    # that are also responsible for how maps work:
    #
    # * {InnerMap}: used for maps that live inside other maps
    # * {BatchMap}: proxies multiple operations into a single Riak update request
    # * {TypedCollection}: a collection of members of a single map, similar
    #   to a Ruby {Hash}
    # * {Flag}: a boolean value inside a map
    # * {Register}: a {String} value inside a map
    # * {InnerCounter}: a {Riak::Crdt::Counter}, but inside a map
    # * {InnerSet}: a {Riak::Crdt::Set}, but inside a map
    # 
    class Map < Base
      attr_reader :counters, :flags, :maps, :registers, :sets
      
      # Create a map instance. If not provided, the default bucket type
      # from {Riak::Crdt} will be used.
      #
      # @param [Bucket] bucket the {Riak::Bucket} for this map
      # @param [String] key the name of the map
      # @param [String] bucket_type the optional bucket type for this map
      # @param [Hash] options
      def initialize(bucket, key, bucket_type=nil, options={})
        super(bucket, key, bucket_type || DEFAULT_BUCKET_TYPES[:map], options)

        initialize_collections
      end

      # Maps are frequently updated in batches. Use this method to get a 
      # {BatchMap} to turn multiple operations into a single Riak update
      # request.
      #
      # @yieldparam [BatchMap] batch_map collects updates and other operations 
      def batch(*args)
        batch_map = BatchMap.new self

        yield batch_map

        write_operations batch_map.operations, *args
      end

      # This method *for internal use only* is used to collect oprations from
      # disparate sources to provide a user-friendly API.
      # 
      # @api private
      def operate(operation, *args)
        batch *args do |m|
          m.operate operation
        end
      end
      
      private
      def vivify(data)
        @counters = TypedCollection.new InnerCounter, self, data[:counters]
        @flags = TypedCollection.new Flag, self, data[:flags]
        @maps = TypedCollection.new InnerMap, self, data[:maps]
        @registers = TypedCollection.new Register, self, data[:registers]
        @sets = TypedCollection.new InnerSet, self, data[:sets]
      end

      def initialize_collections(data={})
        reload if dirty?
      end

      def write_operations(operations, *args)
        op = operator
        op.operate(bucket.name,
                   key,
                   bucket_type,
                   operations,
                   *args
                   )

        # collections break dirty tracking
        reload
      end
    end
  end
end
