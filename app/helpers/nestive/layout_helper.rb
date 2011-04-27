module Nestive
  
  # The Nestive LayoutHelper provides a handful of helper methods for use in your layouts and views.
  #
  # See the documentation for each individual method for detailed information, but at a high level, 
  # your parent layouts define blocks of content. You can define a block and add content to that 
  # block at the same time using either an optional second param, or an ERB block:
  #
  #     # app/views/layouts/global.html.erb
  #     <html>
  #       <head>
  #         <title><%= block :title, "MySite.com" %></title>
  #       </head>
  #       <body>
  #         <div id="content">
  #           <%= block :content %>
  #         </div>
  #         <div id="sidebar">
  #           <%= block :sidebar do %>
  #             <h2>About MySite.com</h2>
  #             <p>...</p>
  #           <% end %>
  #         </div>
  #       </body>
  #     </html>
  #
  # Your child layouts (or views) extend the parent with an ERB block. You can then either `append`,
  # `prepend` or `replace` the content previously assigned to each block by parent layouts (these 
  # methods are similar to Rails' `content_for`, which accept content for the named block with 
  # either an optional second argument, or with an ERB block):
  #
  #     # app/views/layouts/admin.html.erb
  #     <%= extends :global do %>
  #       <% prepend :title, "Admin :: " %>
  #       <% replace :sidebar do %>
  #         <h2>Quick Links</h2>
  #         <ul>
  #           <li>...</li>
  #         </ul>
  #       <% end %>
  #     <% end %>
  #
  #     # app/views/admin/posts/index.html.erb
  #     <%= extends :admin do %>
  #       <% prepend :title, "Posts ::" %>
  #       <% replace :content do %>
  #         Normal view stuff goes here.
  #       <% end %>
  #     <% end %>
  module LayoutHelper
    
    # Declares that the current layour (or view) is inheriting from and extending another layout.
    #
    # @param [Symbol] name
    #   The base name of the file in `layouts/` that you wish to extend (eg `:application` for `layouts/application.html.erb`)
    #
    # @example Extending the `application` layout to create an `admin` layout
    #
    #     # app/views/layouts/admin.html.erb
    #     <%= extends :application do %>
    #       ...
    #     <% end %>
    #
    # @example Extending the `admin` layout in a view (you'll need to render the view with `:layout => nil`)
    #
    #     # app/controllers/admin/posts_controller.rb
    #     class Admin::PostsController < ApplicationController
    #       # You can disable Rails' layout rendering for all actions
    #       layout nil
    #       
    #       # Or disable Rails' layout rendering per-controller
    #       def index
    #         render :layout => nil 
    #       end
    #     end
    #
    #     # app/views/admin/posts/index.html.erb
    #     <%= extends :admin do %>
    #       ...
    #     <% end %>
    def extends(name, &block)
      capture(&block)
      render(:file => "layouts/#{name}")
    end
    
    # Defines a block of content in your layout that can be modified or replaced by child layouts 
    # that extend the current layout. You can optionally add content to the block using either a 
    # second argument String, or as an ERB block.
    #
    # Blocks are defined in the parent layout and modified by the child layouts, but since Nestive
    # allows for multiple levels of extended layouts, a child layout can define a block for it's
    # children to modify.
    #
    # @example Define a block without adding content to it:
    #     <%= block :sidebar %>
    #
    # @example Define a block and add a String of content to it:
    #     <%= block :sidebar, "Some content." %>
    #
    # @example Define a block and add content to it with an ERB block:
    #     <%= block :sidebar do %>
    #       Some content.
    #     <% end %>
    #
    # @example Define a block in a child layout:
    #     <%= extends :global do %>
    #       <%= block :sidebar do %>
    #         Some content.
    #       <% end %>
    #     <% end %>
    #
    # @param [Symbol] name
    #   A unique name to identify this block of content.
    #
    # @todo
    #   Just realised that this methods doesn't accept a String, only a block.
    def block(name, &block)
      append(name, &block)
      render_block(name)
    end
    
    # Appends content to a block previously defined or modified in parent layout(s). You can provide 
    # the content using either a String, or an ERB block.
    #
    # @example Appending content with a String
    #     <% append :sidebar, "Some content." %>
    #
    # @example Appending content with an ERB block:
    #     <% append :sidebar do %>
    #       Some content.
    #     <% end %>
    #
    # @param [Symbol] name
    #   A name to identify the block of content you wish to append to
    #
    # @param [String] content
    #   Optionally provide a String of content, instead of a block. A block will take precedence.
    def append(name, content=nil, &block)
      content = capture(&block) if block_given?
      instruct_block(name, :push, content)
    end

    # Prepends content to a block previously defined or modified in parent layout(s). You can provide 
    # the content using either a String, or an ERB block.
    #
    # @example Prepending content with a String
    #     <% prepend :sidebar, "Some content." %>
    #
    # @example Prepending content with an ERB block:
    #     <% prepend :sidebar do %>
    #       Some content.
    #     <% end %>
    #
    # @param [Symbol] name
    #   A name to identify the block of content you wish to prepend to
    #
    # @param [String] content
    #   Optionally provide a String of content, instead of a block. A block will take precedence.
    def prepend(name, content=nil, &block)
      content = capture(&block) if block_given?
      instruct_block(name, :unshift, content)
    end
    
    # Replaces content to in block previously defined or modified in parent layout(s). You can provide 
    # the content using either a String, or an ERB block.
    #
    # @example Prepending content with a String
    #     <% replace :sidebar, "New content." %>
    #
    # @example Prepending content with an ERB block:
    #     <% replace :sidebar do %>
    #       New content.
    #     <% end %>
    #
    # @param [Symbol] name
    #   A name to identify the block of content you wish to replace
    #
    # @param [String] content
    #   Optionally provide a String of content, instead of a block. A block will take precedence.
    def replace(name, content=nil, &block)
      content = capture(&block) if block_given?
      instruct_block(name, :replace, [content])
    end
    
    private
    
    def instruct_block(name, instruction, value)
      @_block_for ||= {}
      @_block_for[name] ||= []
      @_block_for[name] << [instruction, value]
    end
    
    def render_block(name)
      output = []
      instructions_for_block(name).each do |i|
        output.send(i.first, i.last)
      end
      output.join.html_safe
    end
    
    def instructions_for_block(name)
      instructions = (@_block_for[name] || []).reverse
    end

  end
end