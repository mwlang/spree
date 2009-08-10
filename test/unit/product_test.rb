require 'test_helper'

class ProductTest < Test::Unit::TestCase
  context "A new Product" do 
    context "without variants" do
      setup do
        @product = Factory(:product, :name => 'Foobar Deluxe', :price => 25.0) 
        @master_variant = Variant.find_by_product_id(@product.id, :conditions => ["is_master = ?", true])
      end

      teardown do
        @product.destroy
      end

      should "have a product" do 
        assert @product.is_a?(Product)
      end
      
      should_validate_presence_of :name

      should "have 'Foobar Deluxe' as name" do 
        assert_equal @product.name, "Foobar Deluxe"
      end
      
      should "have 'foobar-deluxe' as permalink" do 
        assert_equal "foobar-deluxe", @product.permalink
      end

      should "not change permalink when name changes" do
        @product.update_attributes :name => 'Foo Bar Deluxe'
        assert_equal @product.name, 'Foo Bar Deluxe'
        assert_equal 'foobar-deluxe', @product.permalink
      end
      
      should "return false for variants?" do
        assert !@product.has_variants?
      end

      should "have a price" do
        assert_equal @product.price, 25.0
      end
      
      should "have a master price" do 
        assert_equal @product.price, @product.master.price
      end

      should "change master price when price changes" do 
        @product.update_attributes(:price => 30.0)
        assert_equal @product.price, @product.master.price
      end
      
      should "change price when master price changes" do 
        @product.master.update_attributes(:price => 50.0)
        assert_equal @product.price, @product.master.price
      end
      
      should "persist a master variant record" do 
        assert_equal @master_variant, @product.master
      end
      
      should "return false for has_stock?" do
        assert !@product.has_stock?
      end

      should "return zero on_hand value" do
        assert_equal 0, @product.on_hand
      end
    end
  end

  context "A Product with units of inventory" do
    setup do 
      @product = Factory(:product_with_inventory)
    end

    should "return true for has_stock?" do
      assert @product.has_stock?
    end
    
  end
  # context "Product instance" do
    # context "when no variants exist" do
    #   
    # context "with only empty variant and no units of inventory" do
    #   setup do
    #     @empty_variant = Factory(:empty_variant, :sku => "FOOSKU")
    #     @product = Factory(:product, :variants => [@empty_variant])
    #   end
    #   should "return false for has_stock?" do
    #     assert !@product.has_stock?
    #   end
    # end
    # 
    # context "with only empty variant and 1 unit of inventory" do
    #   setup do
    #     @product = Factory(:product)
    #     @master_variant = @product.master
    #   end
    #   should "return false for variants?" do
    #     assert !@product.variants?
    #   end
    #   should "return the correct on_hand value" do
    #     assert_equal 1, @product.on_hand
    #   end
    #   should "return the correct sku value" do
    #     assert_equal @empty_variant.sku, @product.sku
    #   end
    #   should "return true for has_stock?" do
    #     assert @product.has_stock?
    #   end
    #   context "when sku is changed" do
    #     setup { @product.sku = "NEWSKU" }
    #     should_change "@empty_variant.sku", :from => "FOOSKU", :to => "NEWSKU"
    #   end
    #   context "when master price changes" do
    #     setup { @product.update_attribute("price", 99.99) }
    #     should "change the empty variant price to the same value" do
    #       assert_in_delta @empty_variant.price, 99.99, 0.00001          
    #     end
    #   end
    #   context "when on_hand is increased" do
    #     setup { @product.update_attribute("on_hand", "5") }
    #     should_change "InventoryUnit.count", :by => 4
    #   end
    #   context "when on_hand is decreased" do
    #     setup do 
    #       @product.update_attribute("on_hand", "0")
    #       @empty_variant.reload
    #     end
    #     should_change "InventoryUnit.count", :by => -1
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