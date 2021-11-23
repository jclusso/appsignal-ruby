describe Appsignal::Utils::QueryParamsSanitizer do

  before do
    Appsignal.config = project_fixture_config("production")
    Appsignal.config[:filter_query_parameters] = ['*']
  end

  describe ".sanitize" do
    context "when only_top_level = true" do
      subject { described_class.sanitize(value, ['*'], true) }

      context "when value is a hash" do
        let(:value) { { "foo" => "bar" } }

        it "should only return the first level of the object" do
          expect(subject).to eq("foo" => "?")
        end

        it "should not modify source value" do
          subject
          expect(value).to eq("foo" => "bar")
        end
      end

      context "when value is a nested hash" do
        let(:value) { { "foo" => { "bar" => "baz" } } }

        it "should only return the first level of the object" do
          expect(subject).to eq("foo" => "?")
        end

        it "should not modify source value" do
          subject
          expect(value).to eq("foo" => { "bar" => "baz" })
        end
      end

      context "when value is an array of hashes" do
        let(:value) { ["foo" => "bar"] }

        it "should sanitize all hash values with a questionmark" do
          expect(subject).to eq("foo" => "?")
        end

        it "should not modify source value" do
          subject
          expect(value).to eq(["foo" => "bar"])
        end
      end

      context "when value is an array" do
        let(:value) { %w[foo bar] }

        it "should only return the first level of the object" do
          expect(subject).to eq("?")
        end

        it "should not modify source value" do
          subject
          expect(value).to eq(%w[foo bar])
        end
      end

      context "when value is a mixed array" do
        let(:value) { [nil, "foo", "bar"] }

        it "should sanitize all hash values with a single questionmark" do
          expect(subject).to eq("?")
        end
      end

      context "when value is a string" do
        let(:value) { "foo" }

        it "should sanitize all hash values with a questionmark" do
          expect(subject).to eq("?")
        end
      end
    end

    context "when only_top_level = false" do
      subject { described_class.sanitize(value, ['*'], false) }

      context "when value is a hash" do
        let(:value) { { "foo" => "bar" } }

        it "should sanitize all hash values with a questionmark" do
          expect(subject).to eq("foo" => "?")
        end

        it "should not modify source value" do
          subject
          expect(value).to eq("foo" => "bar")
        end
      end

      context "when value is a nested hash" do
        let(:value) { { "foo" => { "bar" => "baz" } } }

        it "should replaces values" do
          expect(subject).to eq("foo" => { "bar" => "?" })
        end

        it "should not modify source value" do
          subject
          expect(value).to eq("foo" => { "bar" => "baz" })
        end
      end

      context "when value is an array of hashes" do
        let(:value) { ["foo" => "bar"] }

        it "should sanitize all hash values with a questionmark" do
          expect(subject).to eq(["foo" => "?"])
        end

        it "should not modify source value" do
          subject
          expect(value).to eq(["foo" => "bar"])
        end
      end

      context "when value is an array with less than 10 items" do
        let(:value) { %w[foo bar] }

        it "should sanitize all hash values with a questionmark" do
          expect(subject).to eq(["?"] * 2)
        end
      end

      context "when value is an array with more than 10 items" do
        let(:value) { %w[foo bar] * 10 }

        it "should sanitize the first 10 hash values with a questionmark followed by [...]" do
          expect(subject).to eq((["?"] * 10).push('[...]'))
        end
      end

      context "when value is a mixed array with less than 10 items" do
        let(:value) { [nil, "foo", "bar"] }

        it "should sanitize all hash values with a questionmark" do
          expect(subject).to eq(["?"] * 3)
        end
      end

      context "when value is a mixed array with more than 10 items" do
        let(:value) { [nil, "foo", "bar"] * 5 }

        it "should sanitize the first 10 hash values with a questionmark followed by [...]" do
          expect(subject).to eq((["?"] * 10).push('[...]'))
        end
      end

      context "when value is a string" do
        let(:value) { "bar" }

        it "should sanitize all hash values with a questionmark" do
          expect(subject).to eq("?")
        end
      end
    end
  end

end
