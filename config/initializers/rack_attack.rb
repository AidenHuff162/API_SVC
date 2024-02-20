class Rack::Attack

  blocklist('allow2ban login scrapers') do |req|
    #:maxretry => 30, :findtime => 2.minutes, :bantime => 10.minutes
    Rack::Attack::Allow2Ban.filter(req.ip, maxretry: 30, findtime: 2.minutes, bantime: 10.minutes) do
      req.path == '/api/v1/auth/password' and req.post?
    end
  end

  throttle('admin_signup', limit: 30, period: 2.minutes) do |req|
    'block' if (req.post? and req.host.split('.').first == 'try')
  end

  # blocklisted_response = lambda do |env|
  #   # Using 503 because it may make attacker think that they have successfully
  #   # DOSed the site. Rack::Attack returns 403 for blocklists by default
  #   [ 503, {}, ['Blocked']]
  # end
end
