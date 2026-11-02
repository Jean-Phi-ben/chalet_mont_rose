class Admin::WeeklyRatesController < Admin::BaseController
  before_action :set_weekly_rate, only: %i[edit update destroy]

  def index
    authorize WeeklyRate
    @weekly_rates = policy_scope(WeeklyRate).ordered
  end

  def new
    @weekly_rate = WeeklyRate.new(week_start: next_saturday)
    authorize @weekly_rate
  end

  def create
    @weekly_rate = WeeklyRate.new(weekly_rate_params)
    authorize @weekly_rate
    if @weekly_rate.save
      redirect_to admin_weekly_rates_path, notice: "Tarif enregistré."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @weekly_rate
  end

  def update
    authorize @weekly_rate
    if @weekly_rate.update(weekly_rate_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to admin_weekly_rates_path, notice: "Tarif mis à jour." }
      end
    else
      # Valeur saisie invalide : la ligne est re-rendue avec le message d'erreur
      # (le prix enregistré reste inchangé en base).
      respond_to do |format|
        format.turbo_stream { render :update, status: :unprocessable_entity }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    authorize @weekly_rate
    @weekly_rate.destroy
    redirect_to admin_weekly_rates_path, notice: "Tarif supprimé."
  end

  # Éditeur en lot : applique un prix sur toutes les semaines (samedis) d'une plage.
  def bulk_edit
    authorize WeeklyRate, :create?
  end

  def bulk_update
    authorize WeeklyRate, :create?
    from  = safe_date(params[:from])
    to    = safe_date(params[:to])
    price = params[:price_euros].to_f

    if from.nil? || to.nil? || price <= 0 || to < from
      flash.now[:alert] = "Paramètres invalides : vérifiez les dates et le prix."
      return render :bulk_edit, status: :unprocessable_entity
    end

    price_cents = (price * 100).round
    count = apply_bulk(from, to, price_cents)
    redirect_to admin_weekly_rates_path, notice: "#{helpers.fr_plural(count, 'semaine tarifée')} à #{helpers.money(price_cents)}."
  end

  private

  def set_weekly_rate
    @weekly_rate = WeeklyRate.find(params[:id])
  end

  def weekly_rate_params
    params.require(:weekly_rate).permit(:week_start, :price_euros, :min_weeks, :note, :blocked)
  end

  def next_saturday
    today = Date.current
    today + ((6 - today.wday) % 7)
  end

  def safe_date(value)
    Date.parse(value)
  rescue ArgumentError, TypeError
    nil
  end

  # Crée/met à jour un WeeklyRate pour chaque samedi de la plage [from, to].
  def apply_bulk(from, to, price_cents)
    saturday = from + ((6 - from.wday) % 7)
    count = 0
    while saturday <= to
      rate = WeeklyRate.find_or_initialize_by(week_start: saturday)
      rate.price_cents = price_cents
      rate.save!
      count += 1
      saturday += 7
    end
    count
  end
end
