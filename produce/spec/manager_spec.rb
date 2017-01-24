describe Produce do
  describe "Manager" do
    it "should auto convert string hash keys to symbol keys" do
      Produce.config = FastlaneCore::Configuration.create(Produce::Options.available_options, {
          username: "helmut@januschka.com",
          enabled_features: { "data_protection" => "complete" },
          skip_itc: true
      })

      instance = Produce::DeveloperCenter.new
      features = instance.enabled_features
      expect(features["dataProtection"].value).to eq("complete")
    end

    it "accepts symbol'd hash" do
      Produce.config = FastlaneCore::Configuration.create(Produce::Options.available_options, {
        username: "helmut@januschka.com",
        enabled_features: { data_protection: "complete" },
        skip_itc: true
      })

      instance = Produce::DeveloperCenter.new
      features = instance.enabled_features
      expect(features["dataProtection"].value).to eq("complete")
    end
  end
end
