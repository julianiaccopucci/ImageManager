# ImageManager

ImageManager allows you to easily handling arrays of images that will be accessed and displayed on demand, line in a UITableView or UICollectionView.

ImageManager features:

- Download images on demand
- Hability to cancel a request
- LIFO implementation so when long queues, the user will be displayed with the latest request without the need to wait for the rest to download
- In memory and disk caching memory size adjustable

## Usage

	- (void)viewDidLoad {
    	[super viewDidLoad];
       
   	self.imageManager = [[JIAImageManager alloc] initWithmaxConcurrentOperation:5
                                                              defaultImageOrNil:nil
                                                          downloadingImageOrNil:nil
                                                          showSpinningIndicator:YES
                                                          virtualMemoryCapacity:1000000
                                                             diskMemoryCapacity:1000000];
	}
    
    
    - (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MyCellIdentifier forIndexPath:indexPath];

    	NSString *path = self.objects[indexPath.row];
    
    	[self.imageManager setImageViewImage:cell.imageView withThumbnailPath:path];
    
    	return cell;
	}

