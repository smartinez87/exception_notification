class PostsController < ApplicationController
  # GET /posts/1
  # GET /posts/1.xml
  def show
    @post = Post.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render xml: @post }
    end
  end

  # POST /posts
  # POST /posts.xml
  def create
    @sections = Object.new
    # Have this line raise an exception
    @post = Post.nw(params[:post])

    respond_to do |format|
      if @post.save
        format.html { redirect_to(post_path(@post), notice: 'Post was successfully created.') }
        format.xml  { render xml: @post, status: :created, location: @post }
      else
        format.html { render action: 'new' }
        format.xml  { render xml: @post.errors, status: :unprocessable_entity }
      end
    end
  end
end
