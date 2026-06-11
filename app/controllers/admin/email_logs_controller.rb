class Admin::EmailLogsController < Admin::BaseController
  def index
    authorize EmailLog
    # Seuls les emails liés à une réservation sont conservés (audit metier) ;
    # les logs orphelins (réservations supprimées) sont déjà purgés via le
    # dependent: :destroy de Booking#email_logs.
    @email_logs = EmailLog.includes(:booking).where.not(booking_id: nil).recent.limit(200)
  end

  def show
    @email_log = EmailLog.where.not(booking_id: nil).find(params[:id])
    authorize @email_log
  end
end
