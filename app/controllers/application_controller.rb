require 'open-uri'
require 'net/http'

class ApplicationController < BaseController
	protect_from_forgery with: :exception, :except => [:do_confirm, :thinktank]

	def signout
		logout
		redirect_to (params[:r] || request.referer || home_url)
	end

	def report_problem
		UserMailer.report_problem_email(params[:message], current_user || params[:email]).deliver
		redirect_to site_info_path
	end

	def thinktank
		removeElements = ['font:empty', 'div:empty', 'p:empty', 'form br']

		format_fn = nil

		if params[:url] =~ /(mmsearch|subscribe)/
			url_params = {}
			params_separator = '&'
			titleNode = 'h1'
			if params[:url] == 'mmsearch'
				params_separator = ';'
				titleNode = 'h2'
				url_params[:config] = params[:config]
				url_params[:words]  = URI::encode(params[:words])
				url_params[:page]   = params[:page] if params[:page].present?
				url_params[:format] = params[:format] || :short
				url_params[:method] = params[:method] || :and
				url_params[:sort]   = params[:sort] || :score
			elsif params[:url] == 'subscribe'
				[:email, :pw, :digest].each do |p|
					url_params[p] = params[p]
				end
			end

			@thinktank_page = params[:url]

			url = "http://lists.bikecollectives.org/#{params[:url]}.cgi/thethinktank-bikecollectives.org?" +
					url_params.map{|k,v| ("#{k}=#{v}")}.join(params_separator)

			removeElements << 'table'
			removeElements << 'address'
		elsif params[:url].blank?
			@thinktank_page = 'index'
			removeElements << 'p'
			format_fn = 'index'
		elsif params[:url] =~ /.*\/(thread|author|date|subject)\/?$/
			@thinktank_page = "archives #{$1}"
			format_fn = 'archives'
		end

		url ||= 'http://lists.bikecollectives.org/pipermail/thethinktank-bikecollectives.org/' + (params[:url] ? params[:url] + '.html' : '')
		doc = get_thinktank_content url, 'h1'

		removeElements.each do | e |
			doc.search(e).remove
		end

		if format_fn
			self.send("format_#{format_fn}", doc)
		end

		@content = doc.at('body').inner_html.gsub(/(&nbsp;|&#160;)/i, ' ').html_safe
	end

	private
		def format_archives(doc)
			doc.css('a[name="start"] + ul').remove
			doc.css('a[name="start"] + p').remove
			doc.css('p').remove
			doc.css('hr + i').remove
			doc.css('hr').remove
			doc.css('a[name="start"] + ul').first.set_attribute('class', 'archive-list')
			doc.css('ul.archive-list a[href]').each do |a|
				a.content = CGI.unescapeHTML(a.inner_html.gsub(/^\s*\[TheThinkTank\]\s*(.+?)\s*$/, '\1'))
			end
			nav_links = doc.css('ul.archive-list + ul li:first-child a')
			doc.css('ul.archive-list + ul').remove
			@actions = ''
			nav_links.each do |l|
				l.content = l.inner_html.gsub(/^\s*\[\s*(.+?)\s*\]\s*$/, '\1')
				l.set_attribute('class', "button right #{@archive_page} #{l.inner_html}")
				@actions += l.to_html.to_s
			end
		end

		def format_index(doc)
			table = doc.css('table').first
			table.css('tr').first.remove
			ul = Nokogiri::XML::Node.new('ul', doc)
			ul.set_attribute('class', 'archive-month-list')
			table.css('tr').each do |tr|
				li = Nokogiri::XML::Node.new('li', doc)
				h3 = Nokogiri::XML::Node.new('h3', doc)
				
				tds = tr.css('td')
				month = I18n.l Time.parse(tds.first.inner_html), :format => "%B %Y"
				h3.inner_html = month
				li.add_child(h3)
	
				tr.css('a[href]').each do |l|
					if l.attributes['href'].value =~ /\.gz.*$/
						l.set_attribute('class', 'button download')
						l.inner_html = I18n.t 'thinktank.links.Download'
					else
						l.inner_html = I18n.t "thinktank.links.#{l.inner_html.gsub(/^\s*\[\s*(\w+)\s*\]\s*$/, '\1')}"
					end
					li.add_child(l)
				end
	
				ul.add_child(li)
			end
			table.add_previous_sibling(ul)
			table.remove
		end

		def get_thinktank_cgi_content(url, titleNode = 'h2')
			doc = get_thinktank_content url, titleNode

			@content = ''
			form = doc.search('form')
			form.first.set_attribute('id', 'banner')
			form.first.set_attribute('class', 'thinktank-form')
			@form = form.to_html.html_safe

			@content += '<ul class="search-results">'
			doc.search('strong a').each do |link|
				search_content = ''
				begin
					html = Nokogiri::HTML(open(link.attributes['href'].value.gsub(/^\/?thethinktank/, 'http://lists.bikecollectives.org/pipermail/thethinktank-bikecollectives.org') + '.html'))
					search_content = html.search('pre').first.text
					date = html.css('i').first.inner_html
				rescue
					search_content = ''
					date = ''
				end
				link.attributes['href'].value = link.attributes['href'].value.gsub(/^.*thethinktank\-bikecollectives.org\/(.*)$/, '/thethinktank/\1')
				search_content = search_content.gsub(/^\s*(.{,350}\w)[^\w\-\'].*$/m, '\1&hellip;')
				@content += "<li>#{link.to_html}<time>#{date}</time><p>#{search_content}</p></li>"
			end
			@content += '</ul>'

			@content += '<ul class="pagination">'
			doc.search('img[src]').each do |page|
				if page.attributes["src"].value =~ /button.+\.gif$/
					if page.parent.name == 'a'
						link = page.parent.attributes["href"].value
						@content += "<li><a href=\"#{link}\">#{page.attributes["alt"].value}</a></li>"
					else
						@content += "<li>#{page.attributes["alt"].value}</li>"
					end
				end
			end
			@content += '</ul>'

			@content = @content.html_safe
		end

		def get_thinktank_content(url, titleNode)
			doc = Nokogiri::HTML(open(url))
			base_url = 'http://lists.bikecollectives.org/pipermail/thethinktank-bikecollectives.org/'
			titleElement = doc.at(titleNode)
			titleElement.search('img').remove
			@title = titleElement.inner_html.html_safe
			doc.at(titleNode).remove

			html_anchor = doc.css('pre a[href$="attachment.htm"]')
			if html_anchor
				begin
					html_content = Nokogiri::HTML(open(html_anchor.attribute("href").value).read.html_safe)
					if html_content.css('tt')
						html_content = Nokogiri::HTML(CGI.unescapeHTML(html_content.at('tt').inner_html))
					end
					doc.at('pre').add_previous_sibling('<div class="html-email-content">' + html_content.inner_html + '</div>')
					doc.at('pre').remove
				rescue
				end
			end

			doc.css("a[href]").each do |link|
				if link.attributes["href"].value =~ /^(http:\/\/lists\.bikecollectives\.org\/htdig\.cgi\/thethinktank\-bikecollectives\.org)?(.*)\.html([?#].*)?/
					dir = File.dirname(request.fullpath)
					
					# if we are at the root make sure we go up to the thinktank root
					if File.basename(dir) == dir
						dir = request.fullpath
					end

					href = File.join(dir, $2 + ($3 || ''))
				elsif link.attributes["href"].value =~ /^http:\/\/lists\.bikecollectives\.org\/(mmsearch)\.cgi\/thethinktank\-bikecollectives\.org(.*)$/
					href = '/thethinktank/' + $1 + '/' + $2
				elsif !link.attributes["href"].value.start_with?('http://')
					href = base_url + link.attributes["href"].value.gsub(/^\//, '')
				end
				link.attributes["href"].value = href if href
			end

			doc.css("form[action]").each do |form|
				form.attributes["action"].value = form.attributes["action"].value.gsub(/^(http:\/\/lists\.bikecollectives\.org)?\/(\w+)\.cgi\/thethinktank\-bikecollectives\.org$/, '/thethinktank/\2')
			end

			doc.css('font').each do |font|
				font.attributes.each do |attribute|
					font.remove_attribute(attribute.first)
				end
				font.name = 'span'
			end

			return doc
		end

end
