require "test_helper"
require "net/smtp"

class Api::V1::SendFormControllerTest < ActionDispatch::IntegrationTest
  class SmtpOutage
    def initialize(*)
      @settings = {}
    end

    attr_reader :settings

    def deliver!(*)
      raise Net::SMTPServerBusy, "421 Service not available"
    end
  end

  TINY_JPEG = "/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA="

  setup do
    @domain = "send-form-#{SecureRandom.hex(4)}.example"
    @website = Website.create!(
      name: "ARM",
      domain: @domain,
      email: "contact@arm.example",
      status: "active",
      default_locale: "fr"
    )
    @headers = { "Authorization" => "Bearer #{@website.api_token}", "Accept" => "application/json" }
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.deliveries.clear
  end

  test "attaches up to three reduced jpeg photos and forwards the site fields" do
    assert_emails 1 do
      post api_v1_send_form_path, params: {
        from_email: "jean@example.com",
        from_name: "Jean Dupont",
        subject: "Contact — ARM Services",
        fields: { nom: "Dupont", prénom: "Jean", "Message d'informations": "Photo test" },
        attachments: [ { data: TINY_JPEG }, { data: TINY_JPEG } ]
      }, headers: @headers, as: :json
    end

    assert_response :created
    mail = ActionMailer::Base.deliveries.last
    assert_equal "Nouveau formulaire de #{@domain}", mail.subject
    assert_equal [ "photo-1.jpg", "photo-2.jpg" ], mail.attachments.reject(&:inline?).map(&:filename)
    assert mail.attachments["photo-1.jpg"].body.decoded.b.start_with?("\xFF\xD8\xFF".b)
    body = mail.text_part.body.to_s
    assert_includes body, "Dupont"
    assert_includes body, "Photo test"
    assert_not_includes body, "Jean Dupont"
    assert_not_includes body, "Contact — ARM Services"
    assert_operator body.index("nom"), :<, body.index("prénom")
  end

  test "rejects more than three photos" do
    assert_no_emails do
      post api_v1_send_form_path, params: {
        fields: { nom: "Dupont" },
        attachments: Array.new(4) { { data: TINY_JPEG } }
      }, headers: @headers, as: :json
    end

    assert_response :unprocessable_entity
    assert_equal "Send at most 3 photos.", JSON.parse(response.body)["error"]
  end

  test "does not report success when smtp delivery fails" do
    previous_raise = ActionMailer::Base.raise_delivery_errors
    ActionMailer::Base.raise_delivery_errors = false
    ActionMailer::Base.delivery_method = SmtpOutage

    assert_no_emails do
      post api_v1_send_form_path, params: { message: "Bonjour" }, headers: @headers, as: :json
    end

    assert_response :bad_gateway
    assert_equal "Mail could not be sent. Try again later.", JSON.parse(response.body)["error"]
  ensure
    ActionMailer::Base.raise_delivery_errors = previous_raise
    ActionMailer::Base.delivery_method = :test
  end

  test "rejects a file that is not a jpeg" do
    assert_no_emails do
      post api_v1_send_form_path, params: {
        fields: { nom: "Dupont" },
        attachments: [ { data: Base64.strict_encode64("not-a-photo") } ]
      }, headers: @headers, as: :json
    end

    assert_response :unprocessable_entity
  end
end
