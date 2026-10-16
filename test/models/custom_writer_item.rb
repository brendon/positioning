class CustomWriterItem < ActiveRecord::Base
  belongs_to :list

  positioned on: :list

  def position=(position)
    super((position == "top") ? :first : position)
  end
end
