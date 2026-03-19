require 'rails_helper'

RSpec.describe ToastNotifier do
  describe '.call' do
    it 'creates a new instance and calls #call' do
      notifier_instance = instance_double(ToastNotifier)
      allow(ToastNotifier).to receive(:new).and_return(notifier_instance)
      allow(notifier_instance).to receive(:call)

      ToastNotifier.call(type: "info", title: "Test", message: "Message")

      expect(ToastNotifier).to have_received(:new).with(
        type: "info",
        title: "Test",
        message: "Message",
        link: nil,
        link_text: nil,
        company_id: nil
      )
      expect(notifier_instance).to have_received(:call)
    end
  end

  describe '#call' do
    it 'broadcasts to global stream when no company_id' do
      notifier = ToastNotifier.new(
        type: "info",
        title: "Information",
        message: "This is an info message"
      )

      allow(notifier).to receive(:broadcast_append_to)
      notifier.call

      expect(notifier).to have_received(:broadcast_append_to).with(
        "toast-notifications",
        target: "toast-notifications",
        partial: "layouts/notification",
        locals: {
          type: "info",
          title: "Information",
          message: "This is an info message",
          link: nil,
          link_text: "View"
        }
      )
    end

    it 'broadcasts to company-scoped stream when company_id provided' do
      notifier = ToastNotifier.new(
        type: "success",
        title: "Scan Completed",
        message: "Scan finished",
        company_id: 42
      )

      allow(notifier).to receive(:broadcast_append_to)
      notifier.call

      expect(notifier).to have_received(:broadcast_append_to).with(
        "toast-notifications:company_42",
        target: "toast-notifications",
        partial: "layouts/notification",
        locals: {
          type: "success",
          title: "Scan Completed",
          message: "Scan finished",
          link: nil,
          link_text: "View"
        }
      )
    end

    it 'broadcasts a notification with link' do
      notifier = ToastNotifier.new(
        type: "success",
        title: "Success",
        message: "Operation completed",
        link: "/reports/123",
        link_text: "View Report",
        company_id: 7
      )

      allow(notifier).to receive(:broadcast_append_to)
      notifier.call

      expect(notifier).to have_received(:broadcast_append_to).with(
        "toast-notifications:company_7",
        target: "toast-notifications",
        partial: "layouts/notification",
        locals: {
          type: "success",
          title: "Success",
          message: "Operation completed",
          link: "/reports/123",
          link_text: "View Report"
        }
      )
    end
  end
end
