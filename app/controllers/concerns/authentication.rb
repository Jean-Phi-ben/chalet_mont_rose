module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url
      # Connexion publique = Google (espace client). Le login admin email/mot de
      # passe (/session) n'est volontairement lié nulle part pour ne pas exposer
      # l'existence d'une partie admin.
      redirect_to login_path
    end

    # Destination après connexion : la page demandée avant la redirection vers le
    # login, sinon l'espace client. Source unique utilisée par sessions /
    # registrations / omniauth pour garder un comportement cohérent.
    def after_authentication_url
      session.delete(:return_to_after_authenticating) || account_root_path
    end

    def start_new_session_for(user)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
      end
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_id)
    end
end
