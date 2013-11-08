class BackerObserver < ActiveRecord::Observer
  observe :backer

  def after_create(backer)
    backer.define_key
    backer.define_payment_method
  end

  def before_save(backer)
    Notification.notify_once(:payment_slip,
      backer.user,
      {backer_id: backer.id},
      backer: backer,
      project: backer.project) if backer.payment_choice_was.nil? && backer.payment_choice == 'BoletoBancario'

    if backer.confirmed? and backer.confirmed_at.nil?
      backer.confirmed_at = Time.now
      Notification.notify_once(:confirm_backer,
        backer.user,
        {backer_id: backer.id},
        backer: backer,
        project: backer.project)

      Notification.notify_once(:project_owner_backer_confirmed,
        backer.project.user,
        {backer_id: backer.id},
        backer: backer,
        project: backer.project)

      if (Time.now > backer.project.expires_at  + 7.days) && (user = User.where(email: ::Configuration[:email_payments]).first)
        Notification.notify_once(:backer_confirmed_after_project_was_closed,
          user,
          {backer_id: backer.id},
          backer: backer,
          project: backer.project)
      end
    end
  end

  def after_save(backer)
    Notification.notify_once(:project_success,
      backer.project.user,
      {project_id: backer.project.id},
      project: backer.project) if backer.project.reached_goal?
  end

  def notify_backoffice(backer)
    CreditsMailer.request_refund_from(backer).deliver
  end

  def notify_backoffice_about_canceled(backer)
    user = User.where(email: Configuration[:email_payments]).first
    if user.present?
      Notification.notify_once(:backer_canceled_after_confirmed,
        user,
        {backer_id: backer.id},
        backer: backer)
    end
  end

end
