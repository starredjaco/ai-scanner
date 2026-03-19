class ToastNotifier
    include ActiveModel::Model
    include Turbo::Broadcastable

    def self.call(type: "success", title: "Success!", message: "", link: nil, link_text: nil, company_id: nil)
        new(type: type, title: title, message: message, link: link, link_text: link_text, company_id: company_id).call
    end

    attr_reader :type, :title, :message, :link, :link_text, :company_id

    def initialize(type: "success", title: "Success!", message: "", link: nil, link_text: "View", company_id: nil)
      @type = type
      @title = title
      @message = message
      @link = link
      @link_text = link_text
      @company_id = company_id
    end

    def call
        broadcast_append_to(
            stream_name,
            target: "toast-notifications",
            partial: "layouts/notification",
            locals: {
                type: type,
                title: title,
                message: message,
                link: link,
                link_text: link_text
            }
        )
    end

    private

    def stream_name
      if company_id
        "toast-notifications:company_#{company_id}"
      else
        "toast-notifications"
      end
    end
end
