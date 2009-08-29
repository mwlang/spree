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
  delegate_belongs_to :master, :sku, :price, :weight, :height, :width, :depth, :is_master
  after_create :set_master_variant_defaults
  after_save :set_master_on_hand_to_zero_when_product_has_variants
  
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

  def master_price
    warn "[DEPRECATION] `Product.master_price` is deprecated.  Please use `Product.price` instead."
    master.price
  end
  
  def to_param       
    return permalink unless permalink.blank?
    name.to_url
  end
  
  # returns true if the product has any variants (the master variant is not a member of the variants array)
  def has_variants?
    !variants.empty?
  end

  def on_hand
    has_variants? ? variants.inject(0){|sum, v| sum + v.on_hand} : master.on_hand
  end

  def on_hand=(new_level)
    raise "cannot set on_hand of product with variants" if has_variants?
    master.on_hand = new_level
  end
  
  def has_stock?
    master.in_stock? || !!variants.detect{|v| v.in_stock?}
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

    def set_master_on_hand_to_zero_when_product_has_variants
      master.on_hand = 0 if has_variants?
    end
    
    def set_master_variant_defaults
      self.is_master = true
    end      
end
