date_format = "%m/%d/%Y %H:%M"

def address(xml, order, type)
  name    = "#{type.to_s.titleize}To"
  address = order.send("#{type}_address")

  xml.__send__(name) {
    xml.Name       address.full_name
    xml.Company    address.company

    if type == :ship
      xml.Address1   address.address1
      xml.Address2   address.address2
      xml.City       address.city
      xml.State      address.state ? address.state.abbr : address.state_name
      xml.PostalCode address.zipcode
      xml.Country    address.country.iso
    end

    xml.Phone      address.phone
  }
end

xml.instruct!
xml.Orders(pages: (@shipments.total_count/50.0).ceil) {
  @shipments.each do |shipment|
    order = shipment.order

    xml.Order {
      xml.OrderID        shipment.id
      xml.OrderNumber    Spree::Config.shipstation_number == :order ? order.number : shipment.number
      xml.OrderDate      [order.completed_at, shipment.created_at].max.strftime(date_format)
      xml.OrderStatus    shipment.state
      xml.LastModified   [order.updated_at, shipment.updated_at].max.strftime(date_format)
      xml.ShippingMethod shipment.shipping_method.try(:name)
      xml.OrderTotal     order.total
      xml.TaxAmount      order.tax_total
      xml.ShippingAmount order.ship_total

      if order.shipments.first != shipment
        xml.CustomField1   "Exchange or Replacement Shipment. Not the first shipment for this order."
      end
      xml.CustomField2   shipment.number

=begin
      if order.gift?
        xml.Gift
        xml.GiftMessage
      end
=end

      xml.Customer {
        xml.CustomerCode order.email.slice(0, 50)
        address(xml, order, :bill)
        address(xml, order, :ship)
      }
      xml.Items {
        shipment.manifest.each do |item|
          variant = item.variant
          xml.Item {
            xml.SKU         variant.sku
            xml.Name        [variant.product.name, variant.options_text].join(' ')
            xml.ImageUrl    variant.images.first.try(:attachment).try(:url)
            xml.Weight      variant.weight.to_f
            xml.WeightUnits Spree::Config.shipstation_weight_units
            xml.Quantity    item.quantity
            xml.UnitPrice   item.line_item.price

            if variant.option_values.present?
              xml.Options {
                variant.option_values.each do |value|
                  xml.Option {
                    xml.Name  value.option_type.presentation
                    xml.Value value.name
                  }
                end
              }
            end
          }
        end
      }
    }
  end
}
