module AvoidHtml
    HTML_REGEXP = '\A^(?!.*<(!--)*.*[a-zA-Z][A-Za-z0-9]*.*(--)*>).*$\z'
end