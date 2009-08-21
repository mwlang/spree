# These tests are organized into four product configuration quadrants as follows:
#
#   product     
#     w/o variants  
#         w/o inventory
#         w/inventory
#
#   product     
#     w/variants  
#         w/o inventory
#         w/inventory
#
# Reusable context taken from:
#   http://www.viget.com/extend/reusing-contexts-in-shoulda-with-context-macros/
#
require 'test_helper'

class ProductTest < Test::Unit::TestCase

  def self.should_pass_basic_tests 
    should "have a product" do 
      assert @product.is_a?(Product)
    end
    should_validate_presence_of :name
    should "have 'Foo Bar' as name" do 
      assert_equal @product.name, "Foo Bar"
    end
    should "have 'foo-bar' as permalink" do 
      assert_equal "foo-bar", @product.permalink
    end
    should "not change permalink when name changes" do
      @product.update_attributes :name => 'Foo BaZ'
      assert_equal @product.name, 'Foo BaZ'
      assert_equal 'foo-bar', @product.permalink
    end
    should "not obscure deleted_at" do
      assert true, @product.deleted_at.nil?
    end
    should "have a price" do
      assert_equal 19.99, @product.price
    end
    should "have a master price" do 
      assert_equal @product.price, @product.master.price
      assert_equal @product.master_price, @product.price # deprecated, to be removed
    end
    should "change master price when price changes" do 
      @product.update_attributes(:price => 30.0)
      assert_equal @product.price, @product.master.price
      assert_equal 30.0, @product.price
    end
    should "change price when master price changes" do 
      @product.master.update_attributes(:price => 50.0)
      assert_equal @product.price, @product.master.price
      assert_equal 50.0, @product.price
    end
    should "persist a master variant record" do 
      assert_equal @master_variant, @product.master
    end
    should "have a sku" do 
      assert_equal 'ABC', @product.sku
    end
  end
  
  def self.context_created_product(&block) 
    context "Created Product" do 
      setup do 
        @product = Factory(:product)
        @master_variant = Variant.find_by_product_id(@product.id, :conditions => ["is_master = ?", true])
      end
      teardown do
        @product.destroy
      end
      merge_block(&block) if block_given? 
    end
  end
  
  def self.context_without_variants(&block) 
    context "without variants" do 
      should_pass_basic_tests
      should "return false for has_variants?" do
        assert !@product.has_variants?
      end

      merge_block(&block) if block_given? 
    end
  end

  def self.context_with_variants(&block) 
    context "with variants" do 
      setup do 
        @product.variants << Factory(:variant)
        @first_variant = @product.variants.first
      end
      should_pass_basic_tests
      should "have variants" do 
        assert @product.has_variants?
        assert @first_variant.is_a?(Variant)
      end
      should "return true for has_variants?" do
        assert @product.has_variants?
      end

      merge_block(&block) if block_given? 
    end
  end
  
  def self.context_without_inventory_units(&block) 
    context "without inventory units" do 
      should_pass_basic_tests
      should "return zero on_hand value" do
        assert_equal 0, @product.on_hand
      end
      should "return true for master.has_stock?" do
        assert !@product.master.in_stock?
      end 
      should "return false for has_stock?" do
        assert !@product.has_stock?
      end

      merge_block(&block) if block_given? 
    end
  end

  def self.should_pass_inventory_tests
    should "return true for has_stock?" do 
      assert @product.has_stock? 
    end
    should "have on_hand greater than zero" do 
      assert @product.on_hand > 0
    end
    context "when on_hand is increased" do
      setup { @product.update_attribute("on_hand", 5) }
      should_change "InventoryUnit.count", :by => 4
      should "have the specified on_hand" do
        assert_equal 5, @product.on_hand
      end
    end
    context "when on_hand is decreased" do
      setup { @product.update_attribute("on_hand", 3) }
      should_change "InventoryUnit.count", :by => 2
      should "have the specified on_hand" do
        assert_equal 3, @product.on_hand
      end
    end
  end
  
  def self.context_with_inventory_units(&block) 
    context "with inventory units" do 
      setup do 
        @product.master.inventory_units << Factory(:inventory_unit)
      end
      teardown do
        @product.master.inventory_units.destroy_all
      end
      should_pass_basic_tests
      should_pass_inventory_tests
      merge_block(&block) if block_given? 
    end
  end
  
  context_created_product do
    context_without_variants do
      context_without_inventory_units do 
      end
      context_with_inventory_units do 
        should "be true for has_stock?" do
          assert @product.has_stock?
          assert @product.master.in_stock?
        end 
      end
    end
  end
    
  context_created_product do
    context_with_variants do
      context_without_inventory_units do 
      end
      context_with_inventory_units do 
        setup do
          @product.master.inventory_units.destroy_all
          @first_variant.inventory_units << Factory(:inventory_unit)
        end
        should "be true for has_stock?" do
          assert !@product.master.in_stock?
          assert @first_variant.in_stock?
          assert @product.has_stock?
        end 
      end
    end
  end

  # context "Product instance" do
    # context "with only empty variant and 1 unit of inventory" do
    #   context "when sku is changed" do
    #     setup { @product.sku = "NEWSKU" }
    #     should_change "@empty_variant.sku", :from => "FOOSKU", :to => "NEWSKU"
    #   end
    # end
  # end
  # 
  # context "Product.available" do
  #   setup do
  #     5.times { Factory(:product, :available_on => Time.now - 1.day) }
  #     @unavaiable = Factory(:product, :available_on => Time.now + 2.weeks) 
  #   end
  #   should "only include available products" do
  #     assert_equal 5, Product.available.size
  #     assert !Product.available.include?(@unavailable)
  #   end
  #   teardown { Product.available.destroy_all }
  # end
  # 
  # context "Product.create" do
  #   setup { Product.create(Factory.attributes_for(:product).merge(:on_hand => "7", :variants => [Factory(:empty_variant)])) }
  #   should_change "InventoryUnit.count", :by => 7
  # end
  # 
end