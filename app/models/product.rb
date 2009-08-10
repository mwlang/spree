# PRODUCTS
# Products represent an entity for sale in a store.  
# Products can have variations, called variants 
# Products properties include description, permalink, availability, 
#   shipping category, etc. that do not change by variant.
#
# MASTER VARIANT 
# Every product has one master variant, which stores master price and sku, size and weight, etc.
# The master variant does not have option values associated with it.
# Price, SKU, size, weight, etc. are all delegated to the master variant.
#
# VARIANTS
# All variants can access the product properties directly (via reverse delegation).
# Inventory units are tied to Variant.
# The master variant can have inventory units, but not option values.
# All other variants have option values and may have inventory units.
# 
class Product < ActiveRecord::Base
  after_update :adjust_inventory
  after_create :set_initial_inventory
  
  has_many :product_option_types, :dependent => :destroy
  has_many :option_types, :through => :product_option_types
  has_many :variants, :dependent => :destroy
  has_many :product_properties, :dependent => :destroy, :attributes => true
  has_many :properties, :through => :product_properties
	has_many :images, :as => :viewable, :order => :position, :dependent => :destroy
	
  belongs_to :tax_category
  has_and_belongs_to_many :taxons
  belongs_to :shipping_category
  
  has_one :master, 
    :class_name => 'Variant', 
    :conditions => ["is_master = ?", true], 
    :dependent => :destroy
  delegate_belongs_to :master
  after_create :set_master_variant_defaults

  has_many :variants, 
    :conditions => ["is_master = ?", false], 
    :dependent => :destroy

  validates_presence_of :name

  accepts_nested_attributes_for :product_properties
  
  make_permalink

  alias :options :product_option_types

  # default product scope only lists available and non-deleted products
  named_scope :active, lambda { |*args| { :conditions => ["products.available_on <= ? and products.deleted_at is null", (args.first || Time.zone.now)] } }
  named_scope :not_deleted, lambda { |*args| { :conditions => ["products.deleted_at is null", (args.first || Time.zone.now)] } }
  
  named_scope :available, lambda { |*args| { :conditions => ["products.available_on <= ?", (args.first || Time.zone.now)] } }


  named_scope :with_property_value, lambda { |property_id, value| { :include => :product_properties, :conditions => ["product_properties.property_id = ? AND product_properties.value = ?", property_id, value] } }

                 
  def to_param       
    return permalink unless permalink.blank?
    name.to_url
  end
  
  # returns true if the product has any variants (the master variant is not a member of the variants array)
  def has_variants?
    !variants.empty?
  end

  # Pseduo Attribute.  Products don't really have inventory - variants do.  We want to make the variant stuff transparent
  # in the simple cases, however, so we pretend like we're setting the inventory of the product when in fact, we're really 
  # changing the inventory of the master variant.
  def on_hand
    master.on_hand
  end

  def on_hand=(quantity)
    @quantity = quantity
  end
  
  def has_stock?
    variants.inject(false){ |tf, v| tf ||= v.in_stock }
  end

  # Adding properties and option types on creation based on a chosen prototype
  
  attr_reader :prototype_id
  def prototype_id=(value)
    @prototype_id = value.to_i
  end
  after_create :add_properties_and_option_types_from_prototype
  
  def add_properties_and_option_types_from_prototype
    if prototype_id and prototype = Prototype.find_by_id(prototype_id)
      prototype.properties.each do |property|
        product_properties.create(:property => property)
      end
      self.option_types = prototype.option_types
    end
  end
  
  private
  
    def set_master_variant_defaults
      self.is_master = true
    end
  
    def adjust_inventory
      return if self.new_record?
      return unless @quantity && @quantity.is_integer?    
      new_level = @quantity.to_i
      # don't allow negative on_hand inventory
      return if new_level < 0
      master.save
      master.inventory_units.with_state("backordered").each{|iu|
        if new_level > 0
          iu.fill_backorder
          new_level = new_level - 1
        end
        break if new_level < 1
        }
      
      adjustment = new_level - on_hand
      if adjustment > 0
        InventoryUnit.create_on_hand(master, adjustment)
        reload
      elsif adjustment < 0
        InventoryUnit.destroy_on_hand(master, adjustment.abs)
        reload
      end      
    end
  
    def set_initial_inventory
      return unless @quantity && @quantity.is_integer?    
      master.save
      level = @quantity.to_i
      InventoryUnit.create_on_hand(master, level)
      reload
    end
end
