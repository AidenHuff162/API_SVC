module TeamService
  class BuildPayload

    def prepare_payload(message, summary, title)
      {
        "@type": "MessageCard",
        "@context": "http://schema.org/extensions",
        "themeColor": "0076D7",
        "summary": summary,
        "sections": [{
          "activityTitle": title,
          "activitySubtitle": message
        }]
      }
    end
  end
end
