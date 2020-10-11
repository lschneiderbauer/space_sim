module Clickable
  def on_mouse_click(&block)
    @on_mouse_click ||= []
    @on_mouse_click << block
  end

  def on_mouse_hover(&block)
    @on_mouse_hover ||= []
    @on_mouse_hover << block
  end

  def on_mouse_unhover(&block)
    @on_mouse_unhover ||= []
    @on_mouse_unhover << block
  end

  private

  def trigger_mouse_click(obj = self, id)
    @on_mouse_click.each do |block|
      block.call(obj, id)
    end
  end

  def trigger_mouse_hover(obj = self)
    @on_mouse_hover.each do |block|
      block.call(obj)
    end
  end

  def trigger_mouse_unhover(obj = self)
    @on_mouse_unhover.each do |block|
      block.call(obj)
    end
  end
end
