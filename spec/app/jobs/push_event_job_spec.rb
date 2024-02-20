require 'rails_helper'

RSpec.describe PushEventJob, type: :job do

  after do
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
  end

  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }
  let(:custom_field) { create(:custom_field_with_value) }
  let(:profile_user) { create(:user_with_profile) }
  let(:workstream) { create(:workstream_with_tasks) }
  let(:location) { create(:location) }
  let(:task){ create(:task) }
  let(:manager) { create(:sarah, company: company) }

  it "creates a new additional-fields-updated event in intercom" do
    tempUser = user
    expect{ PushEventJob.perform_later('additional-fields-updated', user, {
          employee_name: tempUser[:first_name] + ' ' + tempUser[:last_name],
          employee_email: tempUser[:email],
          field_name: custom_field.name,
          value_text: custom_field.custom_field_values.first.value_text,
          company: company.name
      })
    }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(1)


  end

  it "creates a new profile-updated event in intercom" do
    tempUser = profile_user
    expect{ PushEventJob.perform_later('profile-updated', profile_user, {
      employee_id: tempUser.id,
      employee_name: tempUser.first_name + ' ' + tempUser.last_name,
      employee_email: tempUser.email,
      about_employee: tempUser.profile.about_you
      })
    }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(1)
  end

  it "creates a new task-update event in intercom" do
    expect{ PushEventJob.perform_later('task-update', user, {
        workstream_name: workstream.name,
        task_name: workstream.tasks.first.name,
        task_type: 'hire',
        task_state: 'in_progress'
      })
    }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(3)
  end

  it "creates a new personal-information-updated event in intercom" do
    expect{ PushEventJob.perform_later('personal-information-updated', user, {
      employee_id: user.id,
      employee_name: user.first_name + ' ' + user.last_name,
      employee_email: user.email,
      company: company.name
    }) }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(2)
  end

  it "creates a new contact-details-updated event in intercom" do
    expect{ PushEventJob.perform_later('contact-details-updated', user, {
      employee_id: user.id,
      employee_name: user.first_name + ' ' + user.last_name,
      employee_email: user.email,
      title: user.title,
      company: company.name
    }) }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(2)
  end

  it "creates a new employee-updated event in intercom" do
    expect{ PushEventJob.perform_later('employee-updated', user, {
      employee_id: user.id,
      employee_name: user.first_name + ' ' + user.last_name,
      employee_email: user.email,
      company: company.name
    }) }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(2)
  end

  it "creates a new settings-updated event in intercom" do
    expect{
      PushEventJob.perform_later('settings-updated', user, {
        company_name: company.name,
        updated: "Outstanding Tasks Emails",
        operation: "Disabled"
      })
    }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(2)
  end

  it "creates a new custom-field-created event in intercom" do
    expect{
      PushEventJob.perform_later('custom-field-created', user, {
        field_name: custom_field.name,
        field_section: custom_field.section
      })
    }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(2)
  end

  it "creates a new custom-field-updated event in intercom" do
    expect{
      PushEventJob.perform_later('custom-field-updated', user, {
        field_name: custom_field.name,
        field_section: custom_field.section
      })
    }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(2)
  end

  it "creates a new custom-field-deleted event in intercom" do
    expect{
      PushEventJob.perform_later('custom-field-deleted', user, {
        field_name: custom_field.name,
        field_section: custom_field.section
      })
    }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(2)
  end

  it "creates a new location-created event in intercom" do
    expect{
      PushEventJob.perform_later('location-created', user, {
        location_name: location.name,
        member_count: location.users_count
      })
    }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(3)
  end

  it "creates a new location-updated event in intercom" do
    expect{
      PushEventJob.perform_later('location-updated', user, {
        location_name: location.name,
        member_count: location.users_count
      })
    }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(3)
  end

  it "creates a new location-deleted event in intercom" do
    expect{
      PushEventJob.perform_later('location-deleted', user, {
        location_name: location.name,
        member_count: location.users_count
      })
    }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(3)
  end

  it "creates a new paperwork-template-created event in intercom" do
    expect{
      PushEventJob.perform_later('paperwork-template-created', user, {
        document_name: "title",
        template_state: "state"
      })
    }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(2)
  end

  it "creates a new paperwork-template-deleted event in intercom" do
    expect{
      PushEventJob.perform_later('paperwork-template-deleted', user, {
        document_name: "title",
        template_state: "state"
      })
    }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(2)
  end

  it "creates a new paperwork-template-finalized event in intercom" do
    expect{
      PushEventJob.perform_later('paperwork-template-finalized', user, {
        document_name: "title",
        template_state: "state"
      })
    }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(2)
  end

  it "creates a new task-created event in intercom" do
    expect{
      PushEventJob.perform_later('task-created', user, {
        task_name: task.name,
        task_type: task.task_type
      })
    }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(3)
  end

  it "creates a new task-updated event in intercom" do
    expect{
      PushEventJob.perform_later('task-updated', user, {
        task_name: task.name,
        task_type: task.task_type
      })
    }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(3)
  end

  it "creates a new task-deleted event in intercom" do
    expect{
      PushEventJob.perform_later('task-deleted', user, {
        task_name: task.name,
        task_type: task.task_type
      })
    }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(3)
  end

  it "creates a new employee-onboarded event in intercom" do
    expect{
      PushEventJob.perform_later('employee-onboarded', user, {
        employee_name: user.first_name + ' ' + user.last_name,
        employee_email: user.email,
        company: company.name
      })
    }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(2)
  end

  it "creates a new manager-updated event in intercom" do
    expect{
      PushEventJob.perform_later('manager-updated', user, {
        employee_id: user.id,
        employee_name: user.first_name + ' ' + user.last_name,
        employee_email: user.email,
        manager: manager.id,
        company: company.name
      })
    }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(3)
  end

  it "creates a new employee-deleted event in intercom" do
    expect{
      PushEventJob.perform_later('employee-deleted', user, {
        employee_id: user.id,
        employee_name: user.first_name + ' ' + user.last_name,
        employee_email: user.email,
        company: company.name
      })
    }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(2)
  end

  it "creates a new workstream-created event in intercom" do
    expect{
      PushEventJob.perform_later('workstream-created', user, {
        workstream_name: workstream.name,
        tasks_count: workstream.tasks_count
      })
    }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(3)
  end

  it "creates a new workstream-deleted event in intercom" do
    expect{
      PushEventJob.perform_later('workstream-deleted', user, {
        workstream_name: workstream.name,
        tasks_count: workstream.tasks_count
      })
    }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(3)
  end

  it "creates a new workstream-updated event in intercom" do
    expect{
      PushEventJob.perform_later('workstream-updated', user, {
        workstream_name: workstream.name,
        tasks_count: workstream.tasks_count
      })
    }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(3)
  end

  it "creates a new preboarding-started event in intercom" do
    expect{
      PushEventJob.perform_later('preboarding-started', user, {
        employee_id: user.id,
        employee_name: user.first_name + ' ' + user.last_name,
        employee_email: user.email
      })
    }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(2)
  end

  it "creates a new preboarding-finished event in intercom" do
    expect{
      PushEventJob.perform_later('preboarding-finished', user, {
        employee_id: user.id,
        employee_name: user.first_name + ' ' + user.last_name,
        employee_email: user.email
      })
    }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(2)
  end

end
