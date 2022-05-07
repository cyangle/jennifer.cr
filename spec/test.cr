require "./spec_helper"

class WebPage < Jennifer::Model::Base
  with_timestamps

  mapping(
    id: Primary64,
    url: String,
    website_id: Int64,
    created_at: Time?,
    updated_at: Time?
  )

  belongs_to :website, Website
end

class Website < Jennifer::Model::Base
  mapping(
    id: Primary64,
    url: String,
  )

  has_many :web_pages, WebPage
end

it "has 1 webpage" do
  void_transaction do
    base_url = "https://en.wikipedia.org/"
    website = Website.create(url: base_url)
    unknown_url = "https://www.teamgantt.com"
    new_webpage = WebPage.create({url: unknown_url, website_id: website.id})
    website = Website.where { c("url") == base_url }.first.not_nil!
    pp website
    pp website.web_pages

    website.web_pages.first.not_nil!.url.should eq(unknown_url)
  end
end
