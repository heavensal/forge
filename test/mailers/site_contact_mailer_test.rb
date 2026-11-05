require "test_helper"

class SiteContactMailerTest < ActionMailer::TestCase
  setup do
    @website = Website.new(
      name: "ARM Services",
      domain: "arm-services-demenagement.fr",
      email: "contact@arm.example",
      default_locale: "fr"
    )
  end

  test "fields are the email body, once, under a generic subject" do
    mail = SiteContactMailer.forward_inquiry(
      website: @website,
      from_email: "jean@example.com",
      from_name: "Jean Dupont",
      subject: "Contact — ARM Services",
      message: "Bonjour",
      fields: { "nom" => "Dupont", "prénom" => "Jean", "email" => "jean@example.com", "message" => "Bonjour" }
    )

    assert_equal "Nouveau formulaire de arm-services-demenagement.fr", mail.subject
    assert_equal [ "contact@arm.example" ], mail.to
    assert_equal [ "jean@example.com" ], mail.reply_to
    assert_equal [ "noreply@1344.fr" ], mail.from
    assert_match(/La Forge/, mail[:from].decoded)

    text = mail.text_part.body.to_s
    html = mail.html_part.body.to_s
    assert_equal 1, text.scan("Bonjour").size
    assert_equal 1, text.scan("Dupont").size
    assert_includes text, "prénom"
    assert_not_includes text, "Jean Dupont"
    assert_not_includes text, "Contact — ARM Services"
    assert_includes text, "Envoyé par La Forge from #1344 Solutions"
    assert_operator html.index(">nom<"), :<, html.index(">prénom<")
    assert_includes html, %(href="mailto:jean@example.com")
    assert_includes html, "Envoyé par La Forge from #1344 Solutions"
    assert mail.attachments["forge-mark.png"].inline?
  end

  test "an english website gets the english shell" do
    @website.default_locale = "en"
    mail = SiteContactMailer.forward_inquiry(
      website: @website,
      fields: { "phone" => "0612345678" }
    )

    assert_equal "New form from arm-services-demenagement.fr", mail.subject
    assert_includes mail.text_part.body.to_s, "Sent by La Forge from #1344 Solutions"
    assert_includes mail.html_part.body.to_s, "phone"
  end

  test "photos are email attachments beside the inline mark" do
    jpeg = Base64.strict_decode64("/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=")
    mail = SiteContactMailer.forward_inquiry(
      website: @website,
      from_email: "jean@example.com",
      fields: { "nom" => "Dupont" },
      photos: [ { filename: "photo-1.jpg", content_type: "image/jpeg", data: jpeg } ]
    )

    files = mail.attachments.reject(&:inline?)
    assert_equal [ "photo-1.jpg" ], files.map(&:filename)
    assert files.first.body.decoded.b.start_with?("\xFF\xD8\xFF".b)
    assert_includes mail.text_part.body.to_s, "Dupont"
  end

  test "message is the body when the site sends no fields" do
    mail = SiteContactMailer.forward_inquiry(
      website: @website,
      from_email: "jean@example.com",
      from_name: "Jean Dupont",
      message: "Bonjour"
    )

    body = mail.text_part.body.to_s
    assert_includes body, "Jean Dupont"
    assert_includes body, "Bonjour"
    assert_includes body, "Nouveau formulaire de arm-services-demenagement.fr"
  end
end
