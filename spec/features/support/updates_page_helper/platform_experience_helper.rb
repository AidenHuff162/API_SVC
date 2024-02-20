def navigate_to_platform_updates
    wait_all_requests
    navigate_to "/#/updates"
end

def platform_experience
    wait_all_requests
    click_button('LEARN MORE')
    wait(2)
    expect(page).to have_content("Team Members (3)")
end
