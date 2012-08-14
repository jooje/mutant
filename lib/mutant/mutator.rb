module Mutant
  # Generator for mutations
  class Mutator
    include Immutable, Abstract

    # Enumerate mutations on node
    #
    # @param [Rubinius::AST::Node] node
    # @param [#call] block
    #
    # @return [self]
    #
    # @api private
    #
    def self.each(node, &block)
      return to_enum(__method__, node) unless block_given?
      Registry.lookup(node.class).new(node, block)

      self
    end

    # Register node class handler
    #
    # @param [Class:Rubinius::AST::Node] node_class
    #
    # @return [undefined]
    #
    # @api private
    #
    def self.handle(node_class)
      Registry.register(node_class,self)
    end
    private_class_method :handle

  private

    # Initialize generator
    #
    # @param [Rubinius::AST::Node] node
    # @param [#call(node)] block
    #
    # @return [undefined]
    #
    # @api private
    #
    def initialize(node, block)
      @node, @block = Mutant.deep_clone(node), block
      IceNine.deep_freeze(@node)
      dispatch
    end

    # Return wrapped node
    #
    # @return [Rubius::AST::Node]
    #
    # @api private
    #
    attr_reader :node
    private :node

    # Dispatch node generations
    #
    # @return [undefined]
    #
    # @api private
    #
    abstract_method :dispatch

    # Append node to generated mutations if node does not equal orignal node
    #
    # @param [Rubinius::AST::Node] node
    #
    # @return [self]
    #
    # @api private
    #
    def emit_safe(node)
      return self unless new?(node)
      emit_unsafe(node)
    end

    # Maximum amount of tries to generate a new node
    MAX_TRIES = 3

    # Call block until it generates a new AST node
    #
    # The primary use of this method is to give the random generated AST nodes
    # a nice interface for retring generation when generation accidentally generated the
    # same AST that is about to be mutated.
    #
    # @yield
    #   Execute block until AST node that does not equal wrapped node is generated by block
    #
    # @return [self]
    #
    # @raise [RuntimeError]
    #   raises RuntimeError in case no new ast node can be generated after MAX_TRIES.
    #
    # @api private
    #
    def emit_new
      MAX_TRIES.times do
        node = yield
        if new?(node)
          emit_unsafe(node)
          return
        end
      end

      raise "New AST could not be generated after #{MAX_TRIES} attempts"
    end

    # Call block with node
    #
    # @param [Rubinius::AST::Node] node
    #
    # @return [self]
    #
    # @api private
    #
    def emit_unsafe(node)
      @block.call(node)

      self
    end

    # Check if node does not equal original node
    #
    # @param [Rubinius::AST::Node] node
    #
    # @return [true]
    #   returns true when node is differend from the node to be mutated
    #
    # @return [false]
    #   returns false otherwise
    #
    # @api private
    #
    def new?(node)
      sexp != node.to_sexp
    end

    # Return s-expressions for node
    #
    # @return [Array]
    #
    # @api private
    #
    def sexp
      node.to_sexp
    end

    # Emit a new AST node
    #
    # @param [Rubinis::AST::Node:Class] node_class
    #
    # @return [Rubinius::AST::Node]
    #
    # @api private
    #
    def emit(node_class, *arguments)
      emit_safe(new(node_class, *arguments))
    end

    # Create a new AST node with same class as wrapped node
    #
    # @return [Rubinius::AST::Node]
    #
    # @api private
    #
    def new_self(*arguments)
      new(node.class, *arguments)
    end

    # Create a new AST node with Rubnius::AST::NilLiteral class
    #
    # @return [Rubinius::AST::Node]
    #
    # @api private
    #
    def new_nil
      new(Rubinius::AST::NilLiteral)
    end

    # Create a new AST node with the same line as wrapped node
    #
    # @param [Class:Rubinius::AST::Node] node_class
    #
    # @return [Rubinius::AST::Node]
    #
    # @api private
    #
    def new(node_class, *arguments)
      node_class.new(node.line, *arguments)
    end

    # Emit a new AST node with same class as wrapped node
    #
    # @return [undefined]
    #
    # @api private
    #
    def emit_self(*arguments)
      emit_safe(new_self(*arguments))
    end

    # Emit a new node with wrapping class for each entry in values
    #
    # @param [Array] values
    #
    # @return [undefined]
    #
    # @api private
    #
    def emit_values(values)
      values.each do |value|
        emit_self(value)
      end
    end

    # Emit element presence mutations
    #
    # @param [Array] elements
    #
    # @return [undefined]
    #
    # @api private
    #
    def emit_element_presence(elements)
      elements.each_index do |index|
        dup_elements = elements.dup
        dup_elements.delete_at(index)
        emit_self(dup_elements)
      end
    end

    # Emit body mutations
    #
    # @return [undefined]
    #
    # @api private
    #
    def emit_body_mutations
      Mutator.each(node.body) do |mutation|
        node = dup_node
        node.body = mutation
        emit_unsafe(node)
      end
    end

    # Emit element mutations
    #
    # @param [Array] elements
    #
    # @return [undefined]
    #
    # @api private
    #
    def emit_elements(elements)
      elements.each_with_index do |element, index|
        dup_elements = elements.dup
        Mutator.each(element).each do |mutation|
          dup_elements[index]=mutation
          emit_self(dup_elements)
        end
      end
    end

    # Emit a new AST node with NilLiteral class
    #
    # @return [Rubinius::AST::NilLiteral]
    #
    # @api private
    #
    def emit_nil
      emit_safe(new_nil)
    end

    # Return AST representing send
    #
    # @param [Rubinius::AST::Node] receiver
    # @param [Symbol] name
    # @param [Rubinius::AST::Node] arguments
    #
    # @return [Rubnius::AST::SendWithArguments]
    #
    # @api private
    #
    def new_send(receiver, name, arguments=nil)
      if arguments
        new(Rubinius::AST::SendWithArguments, receiver, name, arguments)
      else
        new(Rubinius::AST::Send, receiver, name)
      end
    end

    # Return duplicated (unfrozen) node each call
    #
    # @return [Rubinius::AST::Node]
    #
    # @api private
    #
    def dup_node
      node.dup
    end

    memoize :sexp
  end
end
