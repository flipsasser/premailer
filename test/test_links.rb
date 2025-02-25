# frozen_string_literal: true
require __dir__ + '/helper'

class TestLinks < Premailer::TestCase
  def test_empty_query_string
    premailer = Premailer.new('<p>Test</p>', :adapter => :nokogiri, :with_html_string => true, :link_query_string => ' ')
    premailer.to_inline_css
  end

  def test_appending_link_query_string
    qs = 'utm_source=1234&tracking=good&amp;doublescape'
    opts = { :base_url => 'http://example.com/', :link_query_string => qs, :with_html_string => true, :adapter => :nokogiri }

    appendable = [
      '/',
      opts[:base_url],
      'https://example.com/tester',
      'images/',
      "#{opts[:base_url]}test.html?cn=tf&amp;c=20&amp;ord=random",
      '?query=string'
    ]

    not_appendable = [
      '%DONOTCONVERT%',
      '{DONOTCONVERT}',
      '[DONOTCONVERT]',
      '<DONOTCONVERT>',
      '{@msg-txturl}',
      '[[!unsubscribe]]',
      '#relative',
      'tel:5555551212',
      'http://example.net/',
      'mailto:premailer@example.com',
      'ftp://example.com',
      'gopher://gopher.floodgap.com/1/fun/twitpher'
    ]

    html = appendable.collect { |url| "<a href='#{url}'>Link</a>" }

    premailer = Premailer.new(html.to_s, opts)
    premailer.to_inline_css

    premailer.processed_doc.search('a').each do |el|
      href = el.attributes['href'].to_s
      next if href.nil? || href.empty?
      uri = Addressable::URI.parse(href)
      assert_match qs, uri.query, "missing query string for #{el}"
    end

    html = not_appendable.collect { |url| "<a href='#{url}'>Link</a>" }

    premailer = Premailer.new(html.to_s, opts)
    premailer.to_inline_css

    premailer.processed_doc.search('a').each do |el|
      href = el['href']
      next if href.nil? || href.empty?
      assert not_appendable.include?(href), "link #{href} should not be converted: see #{not_appendable}"
    end
  end

  def test_stripping_extra_question_marks_from_query_string
    qs = '??utm_source=1234'

    premailer = Premailer.new("<a href='/test/?'>Link</a> <a href='/test/'>Link</a>", :adapter => :nokogiri, :link_query_string => qs, :with_html_string => true)
    premailer.to_inline_css

    premailer.processed_doc.search('a').each do |a|
      assert_equal '/test/?utm_source=1234', a['href'].to_s
    end

    premailer = Premailer.new("<a href='/test/?123&456'>Link</a>", :adapter => :nokogiri, :link_query_string => qs, :with_html_string => true)
    premailer.to_inline_css

    assert_equal '/test/?123&456&amp;utm_source=1234', premailer.processed_doc.at('a')['href']
  end

  def test_unescape_ampersand
    qs = 'utm_source=1234'

    premailer = Premailer.new("<a href='/test/?q=query'>Link</a>", :adapter => :nokogiri, :link_query_string => qs, :with_html_string => true, :unescaped_ampersand => true)
    premailer.to_inline_css

    premailer.processed_doc.search('a').each do |a|
      assert_equal '/test/?q=query&utm_source=1234', a['href'].to_s
    end
  end

  def test_preserving_links
    html = "<a href='http://example.com/index.php?pram1=one&pram2=two'>Link</a>"
    premailer = Premailer.new(html.to_s, :adapter => :nokogiri, :link_query_string => '', :with_html_string => true)
    premailer.to_inline_css

    assert_equal 'http://example.com/index.php?pram1=one&pram2=two', premailer.processed_doc.at('a')['href']

    html = "<a href='http://example.com/index.php?pram1=one&pram2=two'>Link</a>"
    premailer = Premailer.new(html.to_s, :adapter => :nokogiri, :link_query_string => 'qs', :with_html_string => true)
    premailer.to_inline_css

    assert_equal 'http://example.com/index.php?pram1=one&pram2=two&amp;qs', premailer.processed_doc.at('a')['href']
  end

  def test_resolving_urls_from_string
    ['test.html', '/test.html', './test.html',
     'test/../test.html', 'test/../test/../test.html'].each do |q|
      assert_equal 'http://example.com/test.html', Premailer.resolve_link(q, 'http://example.com/'), q
    end

    assert_equal 'https://example.net:80/~basedir/test.html?var=1#anchor', Premailer.resolve_link('test/../test/../test.html?var=1#anchor', 'https://example.net:80/~basedir/')
  end

  def test_resolving_urls_from_uri
    base_uri = Addressable::URI.parse('http://example.com/')
    ['test.html', '/test.html', './test.html',
     'test/../test.html', 'test/../test/../test.html'].each do |q|
      assert_equal 'http://example.com/test.html', Premailer.resolve_link(q, base_uri), q
    end

    base_uri = Addressable::URI.parse('https://example.net:80/~basedir/')
    assert_equal 'https://example.net:80/~basedir/test.html?var=1#anchor', Premailer.resolve_link('test/../test/../test.html?var=1#anchor', base_uri)

    # base URI with a query string
    base_uri = Addressable::URI.parse('http://example.com/dir/index.cfm?newsletterID=16')
    assert_equal 'http://example.com/dir/index.cfm?link=15', Premailer.resolve_link('?link=15', base_uri)

    # URI preceded by a space
    base_uri = Addressable::URI.parse('http://example.com/')
    assert_equal 'http://example.com/path', Premailer.resolve_link(' path', base_uri)
  end

  def test_resolving_urls_from_html_string
    # The inner URI is on its own line to ensure that the impl doesn't match
    # URIs based on start of line.
    base_uri = "<html><head></head><body>\nhttp://example.com/\n</body>"
    ['test.html', '/test.html', './test.html',
     'test/../test.html', 'test/../test/../test.html'].each do |q|
      Premailer.resolve_link(q, base_uri)
    end
  end

  def test_resolving_urls_in_doc
    # force Nokogiri
    base_file = File.dirname(__FILE__) + '/files/base.html'
    base_url = 'https://my.example.com:8080/test-path.html'
    premailer = Premailer.new(base_file, :base_url => base_url, :adapter => :nokogiri)
    premailer.to_inline_css
    pdoc = premailer.processed_doc
    doc = premailer.doc

    # unchanged links
    ['#l02', '#l03', '#l05', '#l06', '#l07', '#l08',
     '#l09', '#l10', '#l11', '#l12', '#l13'].each do |link_id|
      assert_equal doc.at(link_id).attributes['href'], pdoc.at(link_id).attributes['href'], link_id
    end

    assert_equal 'https://my.example.com:8080/', pdoc.at('#l01').attributes['href'].to_s
    assert_equal 'https://my.example.com:8080/images/', pdoc.at('#l04').attributes['href'].to_s
  end

  def test_convertable_inline_links
    convertible = [
      'my/path/to',
      'other/path',
      '/'
    ]

    html = convertible.collect { |url| "<a href='#{url}'>Link</a>" }
    premailer = Premailer.new(html.to_s, :adapter => :nokogiri, :base_url => "http://example.com", :with_html_string => true)

    premailer.processed_doc.search('a').each do |el|
      href = el.attributes['href'].to_s
      assert(href =~ /http:\/\/example.com/, "link #{href} is not absolute")
    end
  end

  def test_non_convertable_inline_links
    not_convertable = [
      '%DONOTCONVERT%',
      '{DONOTCONVERT}',
      '[DONOTCONVERT]',
      '<DONOTCONVERT>',
      '{@msg-txturl}',
      '[[!unsubscribe]]',
      '#relative',
      'tel:5555551212',
      'mailto:premailer@example.com',
      'ftp://example.com',
      'gopher://gopher.floodgap.com/1/fun/twitpher',
      'cid:13443452066.10392logo.jpeg@inline_attachment'
    ]

    html = not_convertable.collect { |url| "<a href='#{url}'>Link</a>" }

    premailer = Premailer.new(html.to_s, :adapter => :nokogiri, :base_url => "example.com", :with_html_string => true)
    premailer.to_inline_css

    premailer.processed_doc.search('a').each do |el|
      href = el.attributes['href'].to_s
      assert not_convertable.include?(href), "link #{href} should not be converted: see #{not_convertable.inspect}"
    end
  end
end
