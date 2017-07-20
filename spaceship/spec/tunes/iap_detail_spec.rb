describe Spaceship::Tunes::IAPDetail do
  before { Spaceship::Tunes.login }
  let(:client) { Spaceship::Application.client }
  let(:app) { Spaceship::Application.all.first }
  let(:detailed) { app.in_app_purchases.find("go.find.me").edit }

  describe "Details of an IAP" do
    it "Loads full details of a single iap" do
      expect(detailed.class).to eq(Spaceship::Tunes::IAPDetail)
      expect(detailed.reference_name).to eq("created by spaceship")
    end

    it "Read language versions" do
      expect(detailed.versions["de-DE".to_sym][:name]).to eq("test name german1")
    end

    it "humanizes status" do
      expect(detailed.status).to eq("Ready to Submit")
    end

    it "humanizes type" do
      expect(detailed.type).to eq("Consumable")
    end

    it "read pricing_intervals" do
      expect(detailed.pricing_intervals.first[:tier]).to eq(1)
      expect(detailed.pricing_intervals.first[:country]).to eq("WW")
    end

    describe "pricing_info" do
      subject { detailed.pricing_info }

      context "when iap is not cleared for sale yet" do
        before { allow(detailed).to receive(:cleared_for_sale).and_return(false) }

        it "retuns an empty array" do
          expect(subject).to eq([])
        end
      end

      context "when iap is a non-subscription product" do
        let(:pricing_tiers) { client.pricing_tiers }
        let(:interval) do
          { tier: 1, begin_date: nil, end_date: nil, grandfathered: nil, country: "WW" }
        end

        before { expect(detailed).to receive(:pricing_intervals).at_least(:once).and_return([interval]) }

        it "returns all pricing infos of the specified tier" do
          expect(subject).to all(be_an(Spaceship::Tunes::PricingInfo))
          expect(subject.size).to eq(48)
        end

        it "returns the matching entries from the price tier matrix" do
          tier = pricing_tiers.find { |p| p.tier_stem == "1" }
          expect(subject).to match_array(tier.pricing_info)
        end
      end

      context "when iap is a subscription product with territorial pricing" do
        let(:pricing_tiers) { client.subscription_pricing_tiers(app.apple_id) }
        let(:intervals) do
          [
            { tier: 22, begin_date: nil, end_date: nil, grandfathered: {}, country: "QA" },
            { tier: 10, begin_date: nil, end_date: nil, grandfathered: {}, country: "CL" }
          ]
        end

        before { allow(detailed).to receive(:pricing_intervals).at_least(:once).and_return(intervals) }

        it "returns pricing infos for each country" do
          expect(subject).to all(be_an(Spaceship::Tunes::IAPSubscriptionPricingInfo))
          expect(subject.size).to eq(2)
        end

        it "returns the matching entries from the subscription price tier matrix" do
          qa = pricing_tiers
               .find { |t| t.tier_stem == "22" }
               .pricing_info
               .find { |p| p.country_code == "QA" }
          cl = pricing_tiers
               .find { |t| t.tier_stem == "10" }
               .pricing_info
               .find { |p| p.country_code == "CL" }
          expect(subject).to contain_exactly(qa, cl)
        end
      end
    end
  end

  describe "modification" do
    it "saved" do
      detailed.cleared_for_sale = false
      expect(client).to receive(:update_iap!).with(app_id: '898536088', purchase_id: "1195137656", data: detailed.raw_data)
      detailed.save!
    end

    it "saved and changed screenshot" do
      detailed.review_screenshot = "/tmp/fastlane_tests"
      expect(client.du_client).to receive(:upload_purchase_review_screenshot).and_return({ "token" => "tok", "height" => 100, "width" => 200, "md5" => "xxxx" })
      expect(Spaceship::Utilities).to receive(:content_type).and_return("image/jpg")
      expect(client).to receive(:update_iap!).with(app_id: '898536088', purchase_id: "1195137656", data: detailed.raw_data)
      detailed.save!
    end

    it "saved with subscription priceing goal" do
      expect(client).to receive(:update_iap!).with(app_id: '898536088', purchase_id: "1195137656", data: detailed.raw_data)
      detailed.subscription_price_target = { currency: "EUR", tier: 1 }
      detailed.save!
    end

    it "saved with changed pricing detail" do
      edited = app.in_app_purchases.find("go.find.me").edit
      expect(client).to receive(:update_iap!).with(app_id: '898536088', purchase_id: "1195137656", data: edited.raw_data)
      edited.pricing_intervals = [
        {
        country: "WW",
        begin_date: nil,
        end_date: nil,
        tier: 4
        }
      ]
      edited.save!
      expect(edited.pricing_intervals).to eq([{ tier: 4, begin_date: nil, end_date: nil, grandfathered: nil, country: "WW" }])
    end

    it "saved with changed versions" do
      edited = app.in_app_purchases.find("go.find.me").edit
      expect(client).to receive(:update_iap!).with(app_id: '898536088', purchase_id: "1195137656", data: edited.raw_data)
      edited.versions = {
            'en-US' => {
              name: "Edit It",
              description: "Description has at least 10 characters"
            }
          }
      edited.save!
      expect(edited.versions).to eq({ "en-US": { name: "Edit It", description: "Description has at least 10 characters" } })
    end
  end

  describe "Deletion" do
    it "delete" do
      expect(client).to receive(:delete_iap!).with(app_id: '898536088', purchase_id: "1195137656")
      detailed.delete!
    end
  end
end
