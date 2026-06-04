class ReservationsController < ApplicationController
  allow_unauthenticated_access only: %i[create show]

  def create
    @booking = Booking.new(booking_params)
    quote = Pricing.quote(@booking.check_in, @booking.check_out, guests_count: @booking.guests_count.to_i)

    unless quote[:bookable]
      redirect_to calendar_path, alert: "La période sélectionnée n'est pas disponible." and return
    end

    @booking.accommodation_cents = quote[:accommodation_cents]
    @booking.cleaning_fee_cents  = quote[:cleaning_cents]
    @booking.tourist_tax_cents   = quote[:tax_cents]
    @booking.total_price_cents   = quote[:total_cents]
    @booking.deposit_cents       = quote[:deposit_cents]

    if @booking.save
      BookingMailer.new_request_to_owner(@booking).deliver_later
      BookingMailer.acknowledgement_to_client(@booking).deliver_later
      redirect_to reservation_path(@booking.token),
                  notice: "Votre demande a bien été envoyée. Nous vous répondrons rapidement.",
                  status: :see_other
    else
      redirect_to calendar_path,
                  alert: @booking.errors.full_messages.to_sentence,
                  status: :see_other
    end
  end

  def show
    @booking = Booking.find_by!(token: params[:token])
  end

  private

  def booking_params
    params.require(:booking).permit(
      :check_in, :check_out, :guests_count,
      :first_name, :last_name, :email, :phone, :message, :address
    )
  end
end
