# frozen_string_literal: true

class AuthMailer < Devise::Mailer
  protected

  def devise_mail(record, action, opts = {}, &block)
    locale = opts.delete(:locale)
    I18n.with_locale(locale.presence || I18n.locale) do
      attach_forge_mark
      super
    end
  end
end
