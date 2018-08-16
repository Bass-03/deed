RSpec.describe Deed::Google_api do
  it "get task" do
    google = Deed::Google_api.new
    expect(google.credentials).to eq(true)
  end
end
