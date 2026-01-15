
# Use default directory layout
set :source, "source"
set :build_dir, "build"
set :layouts_dir, "layouts"
set :css_dir, "stylesheets"
set :js_dir,  "javascripts"

set :markdown_engine, :redcarpet
set :markdown,
    fenced_code_blocks: true,
    smartypants: true,
    tables: true,
    autolink: true

activate :directory_indexes

# For *.github.io/fluentd-website
set :http_prefix, '/fluentd-website/'

# For fluentd.org
#set :http_prefix, '/'
helpers do
  def is_certified(plugin)
    certified_plugins = YAML.load_file('data/certified_plugins.yml')
    certified_plugins.include?(plugin['name'])
  end
end

# Do not use 'helpers do' block to use them in config.rb.
def read_markdown(file_path)
  title, rest = File.new(file_path).read.split("\n", 2)
  content, rest = rest.split(/\nTAG:/, 2)
  rest ||= ""
  tags, author  = rest.split(/\nAUTHOR:/, 2)
  tags ||= ""
  author ||= "masa"
  title.gsub!(/^#+/, "")
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true, fenced_code_blocks: true)
  return [title, "markdown.render(content)", tags.strip.split(/\s+/).map do |tag| tag.downcase end, author.strip]
end

def read_blog_article(file_path)
  authors = YAML.load_file 'data/authors.yml'
  title, content, tags, author = read_markdown(file_path)
  {
    :title   => title,
    :content => content,
    :tags    => tags,
    # YYYYMMDD_url
    :path    => file_path,
    :date    => Time.parse(file_path.split("_")[0]).to_date,
    :url     => file_path.split('_')[1].gsub(/\.md$/, ""),
    :author_name => authors[author]['name'],
    :author_avatar_url => authors[author]['avatar_url'],
    :author_desc => authors[author]['desc']
  }
end

# Redirect /treasuredata
proxy "/treasuredata/index.html",
      "/index.html",
      locals: { meta_redirect: true,
                canonical: "http://get.treasuredata.com/fluentd.html",
                timeout: 0 }

data.datasources_how.each do |type|
  proxy "/datasources/#{type}/index.html",
        "/datasource_how.html",
        locals: {
          type: type,
        },
        ignore: true
end

testimonials = YAML.load_file("content/testimonials.yaml")
proxy "/testimonials/index.html",
      "testimonials.html",
      locals: {
        testimonials: testimonials,
      },
      ignore: true

recipes = Dir.glob("content/guides/recipes/*.md")
recipes.each do |md|
  type = File.basename(md, ".md")
  proxy "/guides/recipes/#{type}/index.html",
        "solution_recipe.html",
        locals: {
          type: type,
          title: "Guides, Solutions and Examples"
        },
        ignore: true
end

# /casestudy/:company
companies = Dir.glob("content/casestudy/*.md")
companies.each do |md|
  type = File.basename(md, ".md")
  casestudy_title, body_content = File.new(md).read.split("\n", 2)
  casestudy_title.gsub!(/^#+/, "")
  title = casestudy_title
  main_content, profile = body_content.split(/^\n##\s*Profile\s*$/).map {|content|
    Redcarpet::Markdown.new(Redcarpet::Render::HTML,
                            autolink: true,
                            tables: true,
                            fenced_code_blocks: true).render(content)
  }
  proxy "/casestudy/#{type}/index.html",
        "casestudy.html",
        locals: {
          casestudy_title: casestudy_title,
          main_content: main_content,
          profile: profile
        },
        ignore: true
end

# /newsletter
proxy "/newsletter/index.html",
      "newsletter_signup.html",
      layout: "minimal_layout",
      ignore: true

# /plugins
search_categories = {
  "Amazon Web Services" => 'amazon aws cloudwatch',
  "Big Data" => 'hdfs hbase hoop treasure',
  "Filter" => 'filter grep modifier replace geoip parse',
  "Google Cloud Platform" => 'google bigquery',
  "Internet of Things" => 'mqtt',
  "Monitoring" => "growthforecast graphite monitor librato zabbix opentelemetry",
  "Notifications" => "slack irc ikachan hipchat twilio",
  "NoSQL" => 'riak couch mongo couchbase rethink influxdb',
  "Online Processing" => 'norikra anomaly',
  "RDBMS" => 'mysql postgres vertica',
  "Search" => 'splunk elasticsearch sumologic'
}
certified_plugins = YAML.load_file('data/certified_plugins.yml')
plugins = File.new("scripts/plugins.json").read
plugins = JSON.parse(plugins).map{ |e|
  e.merge({'certified' => certified_plugins.include?(e['name']) ? "<center><a href=\"#{config[:http_prefix]}faqs#certified\"><img src=\"#{config[:http_prefix]}images/certified.png\"></a></center>" : ""})
}.to_json
proxy "/plugins/index.html",
      "plugins.html",
      locals: {
        title: "List of Plugins By Category",
        plugins: plugins,
        search_categories: search_categories
      }

# /plugins/all
plugins = File.new("scripts/plugins.json").read
all_plugins = JSON.parse(plugins)
plugins = []
obsolete_plugins = []
filter_plugins = []
parser_plugins = []
formatter_plugins = []

FILTER_PLUGINS = ['fluent-plugin-parser', 'fluent-plugin-geoip', 'fluent-plugin-flatten', 'fluent-plugin-flowcounter-simple', 'fluent-plugin-stats']

def check_plugin_category(name, info, words)
  words.any? { |word| name.include?(word) || info.include?(word) }
end

all_plugins.each { |plugin|
  if plugin["obsolete"]
    obsolete_plugins << plugin
  else
    name = plugin['name']
    info = plugin['info']
    if check_plugin_category(name, info, ['filter', 'Filter']) || FILTER_PLUGINS.include?(name)
      filter_plugins << plugin
    elsif check_plugin_category(name, info, ['parser', 'Parser'])
      parser_plugins << plugin
    elsif check_plugin_category(name, info, ['formatter', 'Formatter'])
      formatter_plugins << plugin
    else
      plugins << plugin
    end
  end
}
proxy "/plugins/all/index.html",
      "plugins/all.html",
      locals: {
        title: "List of All Plugins",
        plugins: plugins,
        filter_plugins: filter_plugins,
        parser_plugins: parser_plugins,
        formatter_plugins: formatter_plugins,
        obsolete_plugins: obsolete_plugins
      }
ignore "plugins/all.html.erb"

# keep compatibility
proxy "/related-projects/index.html",
      "related_projects.html",
      locals: {
        testimonials: testimonials,
      },
      ignore: true

ignore "blog_single.html.erb"

# redirect /download/td_agent
proxy "/download/td_agent/index.html",
      "index.html",
      locals: { meta_redirect: true,
                canonical: "fluent_package",
                timeout: 0 }

# /blog/:article
Dir.glob("source/blog/202512*.md").each do |path|
  caption = File.basename(path.split('_', 2).last, '.md')
  next if caption.nil? || caption.empty?
  article = read_blog_article(path)
  pp article
  title = article[:title]
  recent_articles = [] # read_blog_articles(Dir.glob("content/blog/*.md").sort.reverse.take(N_RECENT_POSTS))
  recent_reminder = [] # read_blog_articles(Dir.glob("content/blog/*.md").sort.reverse).select do |article|
  proxy "/blog/#{caption}/index.html",
        "/blog_single.html",
        locals: {
          title: title,
          article: article,
          recent_articles: recent_articles,
          recent_reminder: recent_reminder
        },
        ignore: true
end

# redirect /enterprise
proxy "/enterprise/index.html",
      "index.html",
      locals: { meta_redirect: true,
                canonical: "/",
                timeout: 0 }

# /sitemap.xml
set :url_root, 'https://www.fluentd.org'
activate :search_engine_sitemap

# /robots.txt
# config.rb
activate :robots, 
  rules: [
    { user_agent: '*', allow: %w[/] }
  ],
  sitemap: 'https://www.fluentd.org/sitemap.xml'
