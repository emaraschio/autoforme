require './spec/spec_helper'

describe AutoForme do
  before(:all) do
    db_setup(:artists=>[[:name, :string]], :albums=>[[:name, :string]], :albums_artists=>[[:album_id, :integer, {:table=>:albums}], [:artist_id, :integer, {:table=>:artists}]])
    model_setup(:Artist=>[:artists, [[:many_to_many, :albums]]], :Album=>[:albums, [[:many_to_many, :artists]]])
  end
  after(:all) do
    Object.send(:remove_const, :Album)
    Object.send(:remove_const, :Artist)
  end

  it "should not show MTM link if there are no many to many associations" do
    app_setup do
      model Artist
      model Album
    end

    visit("/Artist/browse")
    page.html.should_not =~ /MTM/
    visit("/Artist/mtm_edit")
    page.html.should =~ /Unhandled Request/
  end

  it "should have basic many to many association editing working" do
    app_setup do
      model Artist do
        mtm_associations :albums
      end
      model Album
    end

    Artist.create(:name=>'Artist1')
    Album.create(:name=>'Album1')
    Album.create(:name=>'Album2')
    Album.create(:name=>'Album3')

    visit("/Artist/mtm_edit")
    page.find('title').text.should == 'Artist - Many To Many Edit'
    select("Artist1")
    click_button "Edit"

    find('h2').text.should == 'Edit Albums for Artist1'
    all('select')[0].all('option').map{|s| s.text}.should == ["Album1", "Album2", "Album3"]
    all('select')[1].all('option').map{|s| s.text}.should == []
    select("Album1", :from=>"Associate With")
    click_button "Update"
    page.html.should =~ /Updated albums association for Artist/
    Artist.first.albums.map{|x| x.name}.should == %w'Album1'

    all('select')[0].all('option').map{|s| s.text}.should == ["Album2", "Album3"]
    all('select')[1].all('option').map{|s| s.text}.should == ["Album1"]
    select("Album2", :from=>"Associate With")
    select("Album3", :from=>"Associate With")
    select("Album1", :from=>"Disassociate From")
    click_button "Update"
    Artist.first.refresh.albums.map{|x| x.name}.should == %w'Album2 Album3'

    all('select')[0].all('option').map{|s| s.text}.should == ["Album1"]
    all('select')[1].all('option').map{|s| s.text}.should == ["Album2", "Album3"]
  end

  it "should have many to many association editing working with autocompletion" do
    app_setup do
      model Artist do
        mtm_associations :albums
      end
      model Album do
        autocomplete_options({})
      end
    end

    Artist.create(:name=>'Artist1')
    a1 = Album.create(:name=>'Album1')
    a2 = Album.create(:name=>'Album2')
    a3 = Album.create(:name=>'Album3')

    visit("/Artist/mtm_edit")
    select("Artist1")
    click_button "Edit"

    all('select')[0].all('option').map{|s| s.text}.should == []
    fill_in "Associate With", :with=>a1.id
    click_button "Update"
    page.html.should =~ /Updated albums association for Artist/
    Artist.first.albums.map{|x| x.name}.should == %w'Album1'

    all('select')[0].all('option').map{|s| s.text}.should == ["Album1"]
    fill_in "Associate With", :with=>a2.id
    select("Album1", :from=>"Disassociate From")
    click_button "Update"
    Artist.first.refresh.albums.map{|x| x.name}.should == %w'Album2'

    all('select')[0].all('option').map{|s| s.text}.should == ["Album2"]
    select("Album2", :from=>"Disassociate From")
    click_button "Update"
    Artist.first.refresh.albums.map{|x| x.name}.should == []
    all('select')[0].all('option').map{|s| s.text}.should == []
  end

  it "should have inline many to many association editing working" do
    app_setup do
      model Artist do
        inline_mtm_associations :albums
      end
      model Album
    end

    Artist.create(:name=>'Artist1')
    Album.create(:name=>'Album1')
    Album.create(:name=>'Album2')
    Album.create(:name=>'Album3')

    visit("/Artist/edit")
    select("Artist1")
    click_button "Edit"
    select 'Album1'
    click_button 'Add'
    page.html.should =~ /Updated albums association for Artist/
    Artist.first.albums.map{|x| x.name}.should == %w'Album1'

    select 'Album2'
    click_button 'Add'
    Artist.first.refresh.albums.map{|x| x.name}.sort.should == %w'Album1 Album2'

    click_button 'Remove'
    Artist.first.refresh.albums.map{|x| x.name}.should == %w'Album2'

    select 'Album3'
    click_button 'Add'
    Artist.first.refresh.albums.map{|x| x.name}.sort.should == %w'Album2 Album3'
  end

  it "should have inline many to many association editing working with autocompletion" do
    app_setup do
      model Artist do
        inline_mtm_associations :albums
      end
      model Album do
        autocomplete_options({})
      end
    end

    Artist.create(:name=>'Artist1')
    a1 = Album.create(:name=>'Album1')
    a2 = Album.create(:name=>'Album2')
    a3 = Album.create(:name=>'Album3')

    visit("/Artist/edit")
    select("Artist1")
    click_button "Edit"
    fill_in 'Albums', :with=>a1.id.to_s
    click_button 'Add'
    page.html.should =~ /Updated albums association for Artist/
    Artist.first.albums.map{|x| x.name}.should == %w'Album1'

    fill_in 'Albums', :with=>a2.id.to_s
    click_button 'Add'
    Artist.first.refresh.albums.map{|x| x.name}.sort.should == %w'Album1 Album2'

    click_button 'Remove'
    Artist.first.refresh.albums.map{|x| x.name}.should == %w'Album2'

    fill_in 'Albums', :with=>a3.id.to_s
    click_button 'Add'
    Artist.first.refresh.albums.map{|x| x.name}.sort.should == %w'Album2 Album3'
  end

  it "should have working many to many association links on show and edit pages" do
    app_setup do
      model Artist do
        mtm_associations :albums
        association_links :all_except_mtm
      end
      model Album do
        mtm_associations [:artists]
        association_links :all
      end
    end

    visit("/Artist/new")
    fill_in 'Name', :with=>'Artist1'
    click_button 'Create'
    click_link 'Edit'
    select 'Artist1'
    click_button 'Edit'
    page.html.should_not =~ /Albums/

    visit("/Album/new")
    fill_in 'Name', :with=>'Album1'
    click_button 'Create'
    click_link 'Edit'
    select 'Album1'
    click_button 'Edit'
    click_link 'associate'
    select("Artist1", :from=>"Associate With")
    click_button 'Update'
    click_link 'Show'
    select 'Album1'
    click_button 'Show'
    click_link 'Artist1'
    page.current_path.should =~ %r{Artist/show/\d+}
    page.html.should_not =~ /Albums/
  end

  it "should have many to many association editing working when associated class is not using autoforme" do
    app_setup do
      model Artist do
        mtm_associations [:albums]
      end
    end

    Artist.create(:name=>'Artist1')
    Album.create(:name=>'Album1')
    Album.create(:name=>'Album2')
    Album.create(:name=>'Album3')

    visit("/Artist/mtm_edit")
    select("Artist1")
    click_button "Edit"

    all('select')[0].all('option').map{|s| s.text}.should == ["Album1", "Album2", "Album3"]
    all('select')[1].all('option').map{|s| s.text}.should == []
    select("Album1", :from=>"Associate With")
    click_button "Update"
    Artist.first.refresh.albums.map{|x| x.name}.should == %w'Album1'

    all('select')[0].all('option').map{|s| s.text}.should == ["Album2", "Album3"]
    all('select')[1].all('option').map{|s| s.text}.should == ["Album1"]
    select("Album2", :from=>"Associate With")
    select("Album3", :from=>"Associate With")
    select("Album1", :from=>"Disassociate From")
    click_button "Update"
    Artist.first.refresh.albums.map{|x| x.name}.should == %w'Album2 Album3'

    all('select')[0].all('option').map{|s| s.text}.should == ["Album1"]
    all('select')[1].all('option').map{|s| s.text}.should == ["Album2", "Album3"]
  end

  it "should use filter/order from associated class" do
    app_setup do
      model Artist do
        mtm_associations :all
      end
      model Album do
        filter{|ds, req| ds.where(:name=>'A'..'M')}
        order :name
      end
    end

    Artist.create(:name=>'Artist1')
    Album.create(:name=>'E1')
    Album.create(:name=>'B1')
    Album.create(:name=>'O1')

    visit("/Artist/mtm_edit")
    select("Artist1")
    click_button "Edit"

    all('select')[0].all('option').map{|s| s.text}.should == ["B1", "E1"]
    all('select')[1].all('option').map{|s| s.text}.should == []
    select("E1", :from=>"Associate With")
    click_button "Update"
    Artist.first.albums.map{|x| x.name}.should == %w'E1'

    all('select')[0].all('option').map{|s| s.text}.should == ["B1"]
    all('select')[1].all('option').map{|s| s.text}.should == ["E1"]
    select("B1", :from=>"Associate With")
    select("E1", :from=>"Disassociate From")
    click_button "Update"
    Artist.first.refresh.albums.map{|x| x.name}.should == %w'B1'

    all('select')[0].all('option').map{|s| s.text}.should == ["E1"]
    all('select')[1].all('option').map{|s| s.text}.should == ["B1"]

    select("B1", :from=>"Disassociate From")
    Album.where(:name=>'B1').update(:name=>'Z1')
    proc{click_button "Update"}.should raise_error(Sequel::NoMatchingRow)

    visit('/Artist/mtm_edit')
    select("Artist1")
    click_button "Edit"
    select("E1", :from=>"Associate With")
    Album.where(:name=>'E1').update(:name=>'Y1')
    proc{click_button "Update"}.should raise_error(Sequel::NoMatchingRow)

    visit('/Artist/mtm_edit')
    select("Artist1")
    click_button "Edit"
    all('select')[0].all('option').map{|s| s.text}.should == []
    all('select')[1].all('option').map{|s| s.text}.should == []
  end

  it "should support column options on mtm_edit page" do
    app_setup do
      model Artist do
        mtm_associations :albums
        column_options :albums=>{:as=>:checkbox, :remove=>{:name_method=>proc{|obj| obj.name * 2}}}
      end
      model Album do
        display_name{|obj, req| obj.name + "2"}
      end
    end

    Artist.create(:name=>'Artist1')
    Album.create(:name=>'Album1')
    Album.create(:name=>'Album2')
    Album.create(:name=>'Album3')

    visit("/Artist/mtm_edit")
    select("Artist1")
    click_button "Edit"

    check "Album12"
    click_button "Update"
    Artist.first.albums.map{|x| x.name}.should == %w'Album1'

    check "Album1Album1"
    check "Album22"
    check "Album32"
    click_button "Update"
    Artist.first.refresh.albums.map{|x| x.name}.should == %w'Album2 Album3'

    check "Album12"
    check "Album2Album2"
    check "Album3Album3"
  end
end

describe AutoForme do
  before(:all) do
    db_setup(:artists=>[[:name, :string]], :albums=>[[:name, :string]], :albums_artists=>[[:album_id, :integer, {:table=>:albums}], [:artist_id, :integer, {:table=>:artists}]])
    model_setup(:Artist=>[:artists, [[:many_to_many, :albums]], [[:many_to_many, :other_albums, :clone=>:albums]]], :Album=>[:albums, [[:many_to_many, :artists]]])
  end
  after(:all) do
    Object.send(:remove_const, :Album)
    Object.send(:remove_const, :Artist)
  end

  it "should have basic many to many association editing working" do
    app_setup do
      model Artist do
        mtm_associations [:albums, :other_albums]
      end
      model Album
    end

    Artist.create(:name=>'Artist1')
    Album.create(:name=>'Album1')
    Album.create(:name=>'Album2')
    Album.create(:name=>'Album3')

    visit("/Artist/mtm_edit")
    page.find('title').text.should == 'Artist - Many To Many Edit'
    select("Artist1")
    click_button "Edit"

    select('albums')
    click_button "Edit"

    find('h2').text.should == 'Edit Albums for Artist1'
    all('select')[0].all('option').map{|s| s.text}.should == ["Album1", "Album2", "Album3"]
    all('select')[1].all('option').map{|s| s.text}.should == []
    select("Album1", :from=>"Associate With")
    click_button "Update"
    page.html.should =~ /Updated albums association for Artist/
    Artist.first.albums.map{|x| x.name}.should == %w'Album1'

    all('select')[0].all('option').map{|s| s.text}.should == ["Album2", "Album3"]
    all('select')[1].all('option').map{|s| s.text}.should == ["Album1"]
    select("Album2", :from=>"Associate With")
    select("Album3", :from=>"Associate With")
    select("Album1", :from=>"Disassociate From")
    click_button "Update"
    Artist.first.refresh.albums.map{|x| x.name}.should == %w'Album2 Album3'

    all('select')[0].all('option').map{|s| s.text}.should == ["Album1"]
    all('select')[1].all('option').map{|s| s.text}.should == ["Album2", "Album3"]
  end
end
