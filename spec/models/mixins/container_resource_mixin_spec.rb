describe ContainerResourceMixin do
  describe 'container_project' do
    before(:each) do
      allow(MiqServer).to receive(:my_zone).and_return("default")
      hostname = 'host.example.com'
      token = 'theToken'

      @ems = FactoryGirl.create(
        :ems_openshift,
        :name                      => 'OpenShiftProvider',
        :connection_configurations => [{:endpoint       => {:role       => :default,
                                                            :hostname   => hostname,
                                                            :port       => "8443",
                                                            :verify_ssl => OpenSSL::SSL::VERIFY_NONE},
                                        :authentication => {:role     => :bearer,
                                                            :auth_key => token,
                                                            :userid   => "_"}},
                                       {:endpoint       => {:role     => :hawkular,
                                                            :hostname => hostname,
                                                            :port     => "443"},
                                        :authentication => {:role     => :hawkular,
                                                            :auth_key => token,
                                                            :userid   => "_"}}]
      )
      @test_project = FactoryGirl.create(:container_project, :name => 'testproject', :ext_management_system => @ems)

      @test_replicator = FactoryGirl.create(:container_replicator, :name => 'testreplicator', :container_project => @test_project)

      @test_service = FactoryGirl.create(:container_service, :name => 'mysql', :container_project => @test_project)

      @test_delete_service = FactoryGirl.create(:container_service, :name => 'mysql2', :container_project => @test_project)
    end

    it "returns kind known to provider" do
      expect(@test_replicator.kind_in_provider).to eq("ReplicationController")
      expect(@test_service.kind_in_provider).to eq("Service")
    end

    it "returns correct namespace" do
      expect(@test_replicator.namespace).to eq("testproject")
    end

    it "knows the name of the resource" do
      expect(@test_replicator.name).to eq("testreplicator")
    end

    it "gets the resource from the provider as a hash" do
      VCR.use_cassette("mixins/#{described_class.name.underscore}/get_resoruce",
                       :match_requests_on => [:path,]) do
        results = @test_service.get_from_provider
        expect(results.kind_of?(Hash)).to be_truthy
      end
    end

    it "gets correctly named resource from the provider" do
      VCR.use_cassette("mixins/#{described_class.name.underscore}/get_resoruce",
                       :match_requests_on => [:path,]) do
        result = @test_service.get_from_provider
        expect(result[:metadata][:name]).to eq("mysql")
      end
    end

    it "gets the resource from the correct namespace in the provider" do
      VCR.use_cassette("mixins/#{described_class.name.underscore}/get_resoruce",
                       :match_requests_on => [:path,]) do
        results = @test_service.get_from_provider
        expect(results[:metadata][:namespace]).to eq("testproject")
      end
    end

    it "can get the resource from the provider without unique attributes" do
      VCR.use_cassette("mixins/#{described_class.name.underscore}/get_resoruce",
                       :match_requests_on => [:path,]) do
        results = @test_service.get_from_provider_clean
        expect(results[:metadata][:selfLink]).to be_nil
        expect(results[:metadata][:uid]).to be_nil
        expect(results[:metadata][:resourceVersion]).to be_nil
        expect(results[:metadata][:creationTimestamp]).to be_nil
        expect(results[:metadata][:generation]).to be_nil
        expect(results[:metadata][:generation]).to be_nil
        expect(results[:spec][:clusterIP]).to be_nil
        expect(results[:status]).to be_nil
      end
    end

    it "deletes the specified resource" do
      VCR.use_cassette("mixins/#{described_class.name.underscore}/delete_resoruce",
                       :match_requests_on => [:path,]) do
        result = @test_delete_service.delete_from_provider
        expect(result.kind_of?(Hash)).to be_truthy
        result = @test_delete_service.get_from_provider
        expect(result).to be_nil
      end
    end

    it "updates the resource in the provider" do
      VCR.use_cassette("mixins/#{described_class.name.underscore}/update_resoruce",
                       :match_requests_on => [:path,]) do
        result = @test_service.get_from_provider
        result[:metadata][:annotations][:description] = "Description has been updated."
        expect { @test_service.update_in_provider(result) }.not_to raise_exception
        result = @test_service.get_from_provider
        expect(result[:metadata][:annotations][:description]).to eq("Description has been updated.")
      end
    end

    it "raises an error if the kind in the update doesn't match the resource kind" do
      VCR.use_cassette("mixins/#{described_class.name.underscore}/get_resoruce",
                       :match_requests_on => [:path,]) do
        result = @test_service.get_from_provider
        result[:kind] = "Route"
        expect { @test_service.update_in_provider(result) }.to raise_exception(MiqException::MiqProvisionError, "Unexpected Exception while updating object with resource name mysql in namespace namespace testproject.  The update kind Route doesn't match the existing resource kind Service.")
      end
    end
  end
end
